#!/usr/bin/env bash
# Creates the IAP OAuth secret and applies the ingress manifests with the
# nip.io domain substituted from Terraform output.
# Run from the repo root after `terraform apply`.

set -euo pipefail

DOMAIN=$(terraform output -raw mlflow_domain)

echo "Setting up ingress for domain: ${DOMAIN}"

# IAP OAuth credentials — never written to disk
kubectl create secret generic mlflow-iap-secret \
  --namespace=mlflow \
  --from-literal=client_id="$(terraform output -raw mlflow_iap_client_id)" \
  --from-literal=client_secret="$(terraform output -raw mlflow_iap_client_secret)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret 'mlflow-iap-secret' created/updated."

# Apply manifests with domain substituted
sed "s/MLFLOW_DOMAIN_PLACEHOLDER/${DOMAIN}/g" k8s/06-managedcert.yaml | kubectl apply -f -
sed "s/MLFLOW_DOMAIN_PLACEHOLDER/${DOMAIN}/g" k8s/07-ingress.yaml | kubectl apply -f -

echo ""
echo "Done. Next steps:"
echo "  1. Apply the service and backendconfig if not done yet:"
echo "     kubectl apply -f k8s/03-service.yaml"
echo "     kubectl apply -f k8s/05-backendconfig.yaml"
echo "  2. Wait up to 15 min for the TLS cert to provision:"
echo "     kubectl -n mlflow describe managedcertificate mlflow-cert"
echo "  3. Open https://${DOMAIN}"
