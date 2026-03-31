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
SITE_FOLDER="$SCRIPT_DIR/../site"

# Déploiement du stack CloudFormation
echo "⏳ Déploiement du stack CFN..."

aws cloudformation deploy \
    --stack-name "$STACK_NAME" \
    --template-file "$SCRIPT_DIR/../cloudformation/template.yaml" \
    --parameter-overrides BucketName="$BUCKET_NAME" \
    --region "$AWS_REGION" 

echo "✅ Stack CFN déployé !"

echo "⏳ Upload du contenu du site..."
# Copie des fichiers du site vers le bucket
aws s3 sync "$SITE_FOLDER" "s3://$BUCKET_NAME" --region "$AWS_REGION" --delete

# Messages de fin
echo ""
echo "🏁 Déploiement terminé !"
echo "🔗 URL du site : http://$BUCKET_NAME.s3-website.$AWS_REGION.amazonaws.com"