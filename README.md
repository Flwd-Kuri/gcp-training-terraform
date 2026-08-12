# gcp-mlops-infra

Minimal, hand-rolled Terraform foundation for a single-project GCP setup:
remote state, a custom VPC, budget alerting, and a GKE Autopilot cluster —
plus a GitHub Actions pipeline to plan/apply it.

This is intentionally **not** a landing zone (no Fabric FAST, no org
hierarchy, no multi-team IAM). It's scoped to one project so you can get to
the Kubernetes/GitOps learning goals quickly, without fighting enterprise
scaffolding you don't need yet.

## Structure

```
gcp-mlops-infra/
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
            roles/billing.costsManager roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="$ROLE"
done
```

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

## Next steps (not in this repo yet)

- ArgoCD install + app-of-apps pattern for GitOps-managed workloads
- MLflow Helm chart deployed via ArgoCD
- A second environment (e.g. `envs/prod`) once you're ready to split state
