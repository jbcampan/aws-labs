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

#########################################################
# SECTION 1: Version très simple (rapide, sans gestion d'erreurs)
#########################################################

# aws s3 rm s3://"$BUCKET_NAME" --recursive
# aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"


#########################################################
# SECTION 2: Version complefixiée (synchrone, attente avant enchaînement, avec le même résultat)
#########################################################

echo ""
echo "🪣 Traitement du bucket '$BUCKET_NAME'"
echo "-------------------------------------"

# Vider le contenu du bucket
echo "  🗑️  Suppression du contenu…"

if aws s3 rm s3://"$BUCKET_NAME" --recursive; then
    echo "  ✅ Contenu supprimé"
else
    echo "  ❌ Erreur lors de la suppression du contenu"
    exit 1
fi

# Supprimer le stack
echo "  🗑️  Suppression du stack"

if aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$AWS_REGION"; then
    echo "  ⏳ Suppression en cours..."
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$AWS_REGION"
    echo "  ✅ Stack '$STACK_NAME' supprimé avec succès"
else
    echo "  ❌ Erreur lors de la suppression du stack '$STACK_NAME'"
    exit 1
fi

echo ""
echo "🏁 Terminé."