# S3 Labs

## Objectif
Ce dossier contient des cas d’usage autour du service Amazon S3.

## Use cases disponibles
- create-bucket
- delete-bucket
- upload-object
- versioning
- lifecycle-policy

## Prérequis
- AWS CLI installé
- Credentials configurés (aws configure)
- Variables définies dans shared/env/.env

## Organisation
Chaque use case contient plusieurs implémentations :
- bash (AWS CLI)
- terraform (IaC)
- cloudformation
- python (boto3)