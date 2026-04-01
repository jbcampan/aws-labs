#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -a

# Récupération des chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Chargement des variables globales et spécifiques
source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"
set +a

# Exporter pour Terraform
export TF_VAR_bucket_name=$BUCKET_NAME
export TF_VAR_aws_region=$AWS_REGION

# Aller dans le dossier Terraform
cd "$SCRIPT_DIR/../terraform" || exit

# Initialiser et appliquer
terraform init
terraform apply -auto-approve