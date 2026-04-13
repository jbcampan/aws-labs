#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Récupération du chemin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Aller dans le dossier Terraform
cd "$SCRIPT_DIR/../terraform"

# Initialiser et appliquer
terraform init
terraform apply -auto-approve

echo ""
echo "⚠️  Action manuelle requise :"
echo "   Vérifie ta boîte mail (${TF_VAR_alert_email:-ton adresse}) et confirme la subscription SNS."