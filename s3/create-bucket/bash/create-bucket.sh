#!/bin/bash
set -a  # export automatique

# SCRIPT_DIR : récupère le dossier où se trouve ce script, peu importe d'où on l'exécute
# REPO_ROOT : remonte depuis le dossier du script jusqu'à la racine du repo 'aws-labs'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"

set +a  # stop export

#########################################################
# SECTION 1: Création d'un seul bucket
#########################################################

# aws s3api create-bucket \
#     --bucket "$BUCKET_NAME" \
#     --region "$AWS_REGION" \
#     --create-bucket-configuration LocationConstraint="$AWS_REGION"

# # Message de succès ou d'échec
# if [ $? -eq 0 ]; then
#     echo "✅ Bucket '$BUCKET_NAME' créé avec succès"
# else
#     echo "❌ Erreur lors de la création du bucket"
# fi


#########################################################
# SECTION 2: Création de plusieurs buckets
#########################################################

for i in {1..3}; do

    # Vérification si le bucket existe déjà
    if aws s3api head-bucket --bucket "$BUCKET_NAME-$i" 2>/dev/null; then
        echo "⚠️ Bucket '$BUCKET_NAME-$i' existe déjà, passage"
        continue
    fi

    echo ""  # ligne vide de séparation
    echo "🪣 Création du bucket '$BUCKET_NAME-$i'"
    echo "-------------------------------------"

    # Création du bucket
    aws s3api create-bucket \
        --bucket "$BUCKET_NAME-$i" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"

    # Message de succès ou d'échec
    if [ $? -eq 0 ]; then
        echo "  ✅ Bucket '$BUCKET_NAME-$i' créé avec succès"
    else
        echo "  ❌ Erreur lors de la création du bucket"
    fi

done

echo ""
echo "🏁 Terminé."