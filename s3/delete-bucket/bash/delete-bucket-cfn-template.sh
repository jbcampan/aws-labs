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

STACK_NAME="my-bucket-stack"

echo "🚀 Déploiement du stack '$STACK_NAME' (création du Lambda de nettoyage)..."

# 1. Déploiement du stack (crée le Lambda et le Custom Resource)
aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$SCRIPT_DIR/../cloudformation/template.yaml" \
    --parameter-overrides BucketName="$BUCKET_NAME" \
    --region "$AWS_REGION" \
    --capabilities CAPABILITY_NAMED_IAM

echo "🗑️  Suppression du stack '$STACK_NAME' (déclenche le Lambda qui vide et supprime '$BUCKET_NAME')..."

# 2. Suppression du stack — c'est ici que le Custom Resource déclenche le Lambda
aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

# 3. Attente de la suppression complète
aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

echo "✅ Bucket '$BUCKET_NAME' et stack '$STACK_NAME' supprimés avec succès"