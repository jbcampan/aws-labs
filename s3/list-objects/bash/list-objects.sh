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
# SECTION 1: Lister les objets via s3
#########################################################


echo ""  # ligne vide de séparation
echo "Voici la liste des objets contenus dans '$BUCKET_NAME': "
echo "-------------------------------------"


aws s3 ls s3://"$BUCKET_NAME"

#########################################################
# SECTION 2: Lister les objets via s3api
#########################################################

# echo ""  # ligne vide de séparation
# echo "Voici la liste des objets contenus dans '$BUCKET_NAME': "
# echo "-------------------------------------"


# aws s3api list-objects-v2 \
#     --bucket "$BUCKET_NAME"