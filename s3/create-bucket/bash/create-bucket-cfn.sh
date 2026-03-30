#!/bin/bash
set -a

# Récupération des chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Chargement des variables globales et spécifiques
source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"
set +a

STACK_NAME="my-bucket-stack"

# Déploiement du stack CloudFormation
aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$SCRIPT_DIR/../cloudformation/template.yaml" \
    --parameter-overrides BucketName="$BUCKET_NAME" \
    --region "$AWS_REGION" \

if [ $? -eq 0 ]; then
    echo "✅ Bucket '$BUCKET_NAME' créé via CloudFormation avec succès"
else
    echo "❌ Erreur lors de la création via CloudFormation"
fi