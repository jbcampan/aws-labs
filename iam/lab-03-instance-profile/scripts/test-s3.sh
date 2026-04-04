#!/bin/bash
# Script à lancer depuis le terminal de l'instance EC2 (via Session Manager)
# Prérequis : sudo apt update && sudo apt install -y awscli

BUCKET="name-of-my-bucket"          #Changer le nom du bucket (identique à celui de terraform.tfvars mybucket )

echo "=== 1. Liste du bucket ==="
aws s3 ls s3://$BUCKET/

echo "=== 2. Lecture de hello.txt ==="
aws s3 cp s3://$BUCKET/hello.txt -

echo "=== 3. Écriture depuis l'instance ==="
echo "Écrit depuis l'instance sans credentials !" | \
  aws s3 cp - s3://$BUCKET/from-instance.txt

echo "=== 4. Vérification ==="
aws s3 ls s3://$BUCKET/

echo "=== 5. Source des credentials ==="
# Affiche la source des credentials utilisés par la CLI
# La colonne Type doit afficher "iam-role" — preuve qu'aucune clé n'est configurée
# Les credentials sont résolus automatiquement via le metadata service (169.254.169.254)
aws configure list