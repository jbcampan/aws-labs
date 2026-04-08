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