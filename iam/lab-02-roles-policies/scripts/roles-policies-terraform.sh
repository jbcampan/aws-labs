#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
set -a

# Récupération du chemin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

set +a

# Aller dans le dossier Terraform
cd "$SCRIPT_DIR/../terraform" || exit

# Initialiser et appliquer
terraform init
terraform apply -auto-approve

# Récupération des outputs Terraform
export ROLE_ARN=$(terraform output -raw role_arn)
export BUCKET_NAME=$(terraform output -raw bucket_name)

echo "ROLE_ARN=$ROLE_ARN"
echo "BUCKET_NAME=$BUCKET_NAME"

# Lancement du script Python
python3 "$SCRIPT_DIR/assume-role.py"