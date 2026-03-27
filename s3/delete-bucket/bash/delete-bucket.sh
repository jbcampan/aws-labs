#!/bin/bash

set -a # export automatique

# SCRIPT_DIR : récupère le dossier où se trouve ce script, peu importe d'où on l'exécute
# REPO_ROOT : remonte depuis le dossier du script jusqu'à la racine du repo 'aws-labs'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"

set +a # stop export

#########################################################
# SECTION 1: Suppression d'un bucket
#########################################################

# aws s3api delete-bucket \
#     --bucket "$BUCKET_NAME" \
#     --region "$AWS_REGION"

# # Message de succès ou d'échec
# if [ $? -eq 0 ]; then
#     echo "✅ Bucket '$BUCKET_NAME' supprimé avec succès"
# else
#     echo "❌ Erreur lors de la création du bucket"
# fi


#########################################################
# SECTION 2: Suppression de TOUS les buckets
#########################################################

LIST_BUCKETS_NAMES=$(bash ../../list-buckets/bash/list-buckets.sh)

for bucket in $LIST_BUCKETS_NAMES; do

    echo ""  # ligne vide de séparation
    echo "🪣 Traitement du bucket '$bucket'"
    echo "-------------------------------------"

    #Vider le contenu du bucket
    echo "  🗑️  Suppression du contenu…"

    if aws s3 rm s3://"$bucket" --recursive; then
        echo "  ✅ Contenu supprimé"
    else
        echo "  ❌ Erreur lors de la suppression du contenu"
        continue
    fi

    #Supprimer le bucket
    echo "  🗑️  Suppression du bucket…"

    if aws s3api delete-bucket --bucket "$bucket" --region "$AWS_REGION"; then
        echo "  ✅ Bucket '$bucket' supprimé avec succès"
    else
        echo "  ❌ Erreur lors de la suppression du bucket '$bucket'"
    fi

done

echo ""
echo "🏁 Terminé."