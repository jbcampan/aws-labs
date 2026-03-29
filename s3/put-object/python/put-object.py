import logging
import boto3
from botocore.exceptions import ClientError
import os
from pathlib import Path
from dotenv import load_dotenv


# Chemin du fichier actuel
BASE_DIR = Path(__file__).resolve().parent

# Charger le .env 
load_dotenv(BASE_DIR / '../config.env')

# 🔹 Debug : vérifier que les fichiers sont bien chargés
# print("DEBUG BUCKET:", os.getenv('BUCKET_NAME'))

#Récupérer les variables
aws_bucket_name = os.getenv('BUCKET_NAME')
file_path = BASE_DIR / '../hello.txt'

def upload_file(file_name, bucket, object_name=None):

    # Si S3 object_name n'est pas spécifié, utiliser file_name
    if object_name is None:
        object_name = os.path.basename(file_name)

    # Envoyer le fichier
    s3_client = boto3.client('s3')
    try:
        s3_client.upload_file(file_name, bucket, object_name)
        print(f"✅ Fichier '{object_name}' envoyé avec succès dans le bucket '{bucket}'")
        return True
    except ClientError as e:
        print(f"❌ Erreur lors de l'envoi du fichier : {e}")
        return False

if __name__ == "__main__":
    upload_file(str(file_path),aws_bucket_name)