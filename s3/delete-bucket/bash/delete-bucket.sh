#!/bin/bash

set -a # export automatique

# SCRIPT_DIR : récupère le dossier où se trouve ce script, peu importe d'où on l'exécute
# REPO_ROOT : remonte depuis le dossier du script jusqu'à la racine du repo 'aws-labs'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"

set +a # stop export

# Suppression du bucket
aws s3api delete-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$AWS_REGION"

# Message de succès ou d'échec
if [ $? -eq 0 ]; then
    echo "✅ Bucket '$BUCKET_NAME' supprimé avec succès"
else
    echo "❌ Erreur lors de la création du bucket"
fi