# gcp-training-terraform

Minimal, hand-rolled Terraform foundation for a single-project GCP setup:
remote state, a custom VPC, budget alerting, and a GKE Autopilot cluster —
plus a GitHub Actions pipeline to plan/apply it.

This is intentionally **not** a landing zone (no Fabric FAST, no org
hierarchy, no multi-team IAM). It's scoped to one project so you can get to
the Kubernetes/GitOps learning goals quickly, without fighting enterprise
scaffolding you don't need yet.

## Structure

```
gcp-training-terraform/
├── backend.tf          # remote state config (GCS)
├── providers.tf         # provider + versions
├── variables.tf         # input variables
├── network.tf            # custom VPC + subnet + Cloud NAT
├── budget.tf              # billing budget + alert thresholds
├── gke.tf                 # GKE Autopilot cluster
├── outputs.tf              # useful outputs (cluster name, endpoint, etc.)
├── terraform.tfvars.example
└── .github/workflows/terraform.yml   # plan on PR, apply on merge to main
```

## One-time manual bootstrap (before Terraform can run)

Terraform can't create the bucket it stores its own state in, and it
shouldn't create the identity that's allowed to run it — those two things
need to exist first. This is normal, not a workaround.

```bash
# 1. Set your project (must already exist, or create via console/gcloud)
export PROJECT_ID="your-project-id"
export REGION="europe-west1"          # pick your region
export BILLING_ACCOUNT_ID="XXXXXX-XXXXXX-XXXXXX"

gcloud config set project "$PROJECT_ID"

# 2. Enable the APIs Terraform will need
gcloud services enable \
  compute.googleapis.com \
  container.googleapis.com \
  billingbudgets.googleapis.com \
  iam.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com

# 3. Create the GCS bucket for Terraform state
gsutil mb -l "$REGION" "gs://${PROJECT_ID}-tfstate"
gsutil versioning set on "gs://${PROJECT_ID}-tfstate"

# 4. Create a dedicated Terraform service account (least-privilege, not owner)
gcloud iam service-accounts create terraform-runner \
  --display-name="Terraform Runner"

# Grant only what's needed for this repo's resources.
# Start narrow and add roles as Terraform complains — don't grant Owner.
for ROLE in roles/compute.networkAdmin roles/container.admin \
            roles/billing.costsManager roles/iam.serviceAccountUser \
            roles/cloudsql.admin roles/servicenetworking.networksAdmin \
            roles/storage.admin roles/iam.serviceAccountAdmin; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$ROLE"
done

# The state bucket itself needs a bucket-scoped grant, separate from the
# project-level roles above — this one is easy to miss since it doesn't
# show up on the project's IAM page, only on the bucket's own permissions.
gsutil iam ch \
  "serviceAccount:terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com:roles/storage.objectAdmin" \
  "gs://${PROJECT_ID}-tfstate"

# Budget alert notification channels are also their own permission surface.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/monitoring.notificationChannelEditor"
```

**What the new roles cover, since each was a real error we hit building
this incrementally:**
- `roles/cloudsql.admin` — creating the Postgres instance, database, user
- `roles/servicenetworking.networksAdmin` — the private VPC peering Cloud SQL needs for a private IP
- `roles/storage.admin` — creating the MLflow artifact **bucket** (distinct from `storage.objectAdmin`, which only lets you read/write objects *inside* an existing bucket)
- `roles/iam.serviceAccountAdmin` — creating the `mlflow-workload` Google service account and its Workload Identity binding

## Workload Identity Federation (for GitHub Actions — no JSON keys)

Set this up once so GitHub Actions can authenticate as `terraform-runner`
without a downloaded service-account key sitting in a repo secret.

```bash
gcloud iam workload-identity-pools create "github-pool" \
  --location="global" --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com"

gcloud iam service-accounts add-iam-policy-binding \
  "terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-pool/attribute.repository/YOUR_GH_ORG/YOUR_REPO"
```

Then add these as GitHub Actions **repo secrets** (not values, just wiring —
no key material):
- `GCP_WORKLOAD_IDENTITY_PROVIDER`: full resource name of the provider above
- `GCP_SERVICE_ACCOUNT`: `terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com`
- `GCP_PROJECT_ID`, `TF_STATE_BUCKET`: your values

## Local usage

```bash
cp terraform.tfvars.example terraform.tfvars
# fill in project_id, billing_account_id, budget_amount, region, etc.

terraform init \
  -backend-config="bucket=${PROJECT_ID}-tfstate" \
  -backend-config="prefix=terraform/state"

terraform plan
terraform apply
```

## What this deploys

- A custom VPC + subnet (never the `default` network) with Cloud NAT so
  Autopilot nodes have egress without public IPs
- A billing budget with alerts at 50% / 90% / 100% of a monthly amount you set
- A GKE **Autopilot** cluster inside that VPC

## Step 4: MLflow on GKE

Terraform provisions the storage layer (`mlflow-backend.tf`): a private-IP
Cloud SQL Postgres instance, a GCS bucket for artifacts, and a Google
service account bound to a Kubernetes service account via Workload
Identity — so the MLflow pod authenticates to GCS with no downloaded key,
and to Cloud SQL over a private network path.

Raw YAML (`k8s/`) deploys MLflow itself on top of that. This is
deliberately not Helm yet — seeing the plain objects first is what makes
Helm/ArgoCD click later, rather than starting from abstraction.

**1. Apply the Terraform** (adds Cloud SQL, GCS bucket, Workload Identity
plumbing to what you already have):
```bash
terraform apply
```

**2. Get cluster credentials**
```bash
$(terraform output -raw get_credentials_command)
```

**3. Fill in the two placeholders** using Terraform's outputs:
```bash
terraform output mlflow_workload_gsa_email   # -> k8s/01-serviceaccount.yaml
terraform output mlflow_db_private_ip        # -> k8s/02-deployment.yaml
terraform output mlflow_artifact_bucket      # -> k8s/02-deployment.yaml
```
Replace `GSA_EMAIL_PLACEHOLDER`, `SQL_PRIVATE_IP_PLACEHOLDER`, and
`ARTIFACT_BUCKET_PLACEHOLDER` in those two files with the real values.

**4. Create the DB secret directly from Terraform state** (never written
to a file, nothing to accidentally commit):
```bash
./k8s/create-db-secret.sh
```

**5. Apply the manifests**
```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-serviceaccount.yaml
kubectl apply -f k8s/02-deployment.yaml
kubectl apply -f k8s/03-service.yaml
kubectl -n mlflow rollout status deployment/mlflow
```

**6. Reach it locally**
```bash
kubectl -n mlflow port-forward svc/mlflow 5000:5000
# open http://localhost:5000
```

If the pod fails on the GCS or Postgres connection specifically (not on
the pip install), the usual cause is the Workload Identity binding not
having propagated yet — it can take a minute or two after `terraform
apply`. Check with:
```bash
kubectl -n mlflow logs deployment/mlflow
```

## Next steps (not in this repo yet)

- Bake `psycopg2-binary` / `gcsfs` into a custom MLflow image instead of
  installing them at pod start (this k8s manifest cuts that corner on
  purpose, to keep the first pass simple)
- Repackage `k8s/*.yaml` as a Helm chart — same objects, templated
- ArgoCD install + app-of-apps pattern for GitOps-managed workloads
- A second environment (e.g. `envs/prod`) once you're ready to split state
