#!/bin/bash

set -a # export automatique

# SCRIPT_DIR : récupère le dossier où se trouve ce script, peu importe d'où on l'exécute
# REPO_ROOT : remonte depuis le dossier du script jusqu'à la racine du repo 'aws-labs'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"

set +a # stop export

LOCAL_FOLDER="$SCRIPT_DIR/../local-folder"

#########################################################
# SECTION 1: Synchroniser mon bucket s3 avec mon dossier local-folder
#########################################################

aws s3 sync "$LOCAL_FOLDER" s3://"$BUCKET_NAME" 

# Message de succès ou d'échec
if [ $? -eq 0 ]; then
    echo "✅ Dossier synchronisé avec succès"
else
    echo "❌ Erreur lors de la synchronisation du dossier"
fi


#########################################################
# SECTION 2: Synchroniser mon dossier local-folder avec mon s3
#########################################################

# if aws s3 sync "s3://$BUCKET_NAME" "$LOCAL_FOLDER" --delete; then
#     echo "✅ Dossier synchronisé depuis S3"
# else
#     echo "❌ Erreur lors de la synchronisation depuis S3"
# fi