#!/bin/bash

set -e  # stop si erreur
set -a # export automatique

# SCRIPT_DIR : récupère le dossier où se trouve ce script, peu importe d'où on l'exécute
# REPO_ROOT : remonte depuis le dossier du script jusqu'à la racine du repo 'aws-labs'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/shared/config/.env"
source "$SCRIPT_DIR/../config.env"

set +a # stop export

SITE_FOLDER="$SCRIPT_DIR/../site"

#########################################################
# ETAPE 1: Créer le bucket
#########################################################
echo ""
echo "🚀 Création du bucket S3..."
echo "-------------------------------------"

if aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"; then
    echo "  ✅ Bucket créé"
else
    echo "  ❌ Erreur lors de la création du bucket"
fi

#########################################################
# ETAPE 2: Désactiver le blocage public
#########################################################
echo ""
echo "🔓 Désactivation du blocage public..."
echo "-------------------------------------"

aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false

# Message de succès
echo "  ✅ Blocage public désactivié avec succès"


#########################################################
# ETAPE 3: Ajouter la policy publique
#########################################################
echo ""
echo "📜 Ajout de la policy publique..."
echo "-------------------------------------"

aws s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Effect\": \"Allow\",
                \"Principal\": \"*\",
                \"Action\": \"s3:GetObject\",
                \"Resource\": \"arn:aws:s3:::$BUCKET_NAME/*\"
            }
        ]
    }"

# Message de succès
echo "  ✅ Policy ajoutée avec succès"


#########################################################
# ETAPE 4: Upload du site
#########################################################
echo ""
echo "📤 Upload du contenu du site..."
echo "-------------------------------------"

if aws s3 sync "$SITE_FOLDER" "s3://$BUCKET_NAME"; then
    echo "  ✅ Téléchargement des fichiers réussi"
else
    echo "  ❌ Erreur lors du téléchargement des fichiers"
fi

#########################################################
# ETAPE 5: Activer le mode site web
#########################################################
echo ""
echo "🌐 Activation du mode site web..."
echo "-------------------------------------"

aws s3 website "s3://$BUCKET_NAME" \
    --index-document index.html 

# Message de succès
echo "  ✅ Site web activé avec succès"



echo ""
echo "🏁 Déploiement terminé !"
echo "🔗 URL du site : http://$BUCKET_NAME.s3-website.$AWS_REGION.amazonaws.com"