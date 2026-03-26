#!/bin/bash
set -a  # export automatique

# SCRIPT_DIR : récupère le dossier où se trouve ce script, peu importe d'où on l'exécute
# REPO_ROOT : remonte depuis le dossier du script jusqu'à la racine du repo 'aws-labs'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"

set +a  # stop export

# Création du bucket
aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --create-bucket-configuration LocationConstraint="$AWS_REGION"

# Message de succès
echo "✅ Bucket '$BUCKET_NAME' créé avec succès dans la région '$AWS_REGION'."