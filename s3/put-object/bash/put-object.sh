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
# SECTION 1: Création d'un objet via s3
#########################################################

# aws s3 cp "$SCRIPT_DIR/../hello.txt" s3://"$BUCKET_NAME"


# # Message de succès ou d'échec
# if [ $? -eq 0 ]; then
#     echo "✅ Fichier hello.txt envoyé avec succès"
# else
#     echo "❌ Erreur lors de l'envoi du fichier'"
# fi

#########################################################
# SECTION 2: Création d'un objet via s3api
#########################################################

aws s3api put-object \
    --bucket "$BUCKET_NAME" \
    --key "hello.txt" \
    --body "$SCRIPT_DIR/../hello.txt"


# Message de succès ou d'échec
if [ $? -eq 0 ]; then
    echo "✅ Fichier hello.txt envoyé avec succès"
else
    echo "❌ Erreur lors de l'envoi du fichier'"
fi