#!/usr/bin/env bash
# Creates the mlflow-db Secret directly from Terraform's output, piped
# straight into kubectl — the password never touches disk as a file,
# so there's nothing here to accidentally commit.
#
# Run from the repo root, after `terraform apply` and after you've run
# `gcloud container clusters get-credentials` (see outputs.tf).

set -euo pipefail

kubectl create secret generic mlflow-db \
  --namespace=mlflow \
  --from-literal=username=mlflow \
  --from-literal=password="$(terraform output -raw mlflow_db_password)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret 'mlflow-db' created/updated in namespace 'mlflow'."
