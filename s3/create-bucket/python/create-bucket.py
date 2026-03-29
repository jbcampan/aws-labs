from pathlib import Path
from dotenv import load_dotenv
import os
import boto3
from botocore.exceptions import ClientError

# Chemin du fichier actuel
BASE_DIR = Path(__file__).resolve().parent

# Charger les .env 
load_dotenv(BASE_DIR / '../../../shared/config/.env')
load_dotenv(BASE_DIR / '../config.env')

# 🔹 Debug : vérifier que les fichiers sont bien chargés
# print("DEBUG REGION:", os.getenv('AWS_REGION'))
# print("DEBUG BUCKET:", os.getenv('BUCKET_NAME'))

#Récupérer les variables
aws_region = os.getenv('AWS_REGION')
aws_bucket_name = os.getenv('BUCKET_NAME')


def create_bucket(bucket_name, region):

    """Créer un bucket S3 dans une région spécifiée"""

    print("")  # ligne vide de séparation
    print(f"🪣 Création du bucket '{bucket_name}'")
    print("-------------------------------------")

    try:
        s3_client = boto3.client('s3', region_name=region)
        bucket_config = {}
        if region != 'us-east-1':
            bucket_config['CreateBucketConfiguration'] = {'LocationConstraint': region}

        s3_client.create_bucket(Bucket=bucket_name, **bucket_config)
        print(f"  ✅ Bucket '{bucket_name}' créé avec succès en {region} !")
        return True

    except ClientError as e:
        print(f"  ❌ Erreur lors de la création du bucket : {e}")
        return False


if __name__ == "__main__":
    create_bucket(aws_bucket_name,aws_region)