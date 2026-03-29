import logging
import boto3
from botocore.exceptions import ClientError
import os
from pathlib import Path
from dotenv import load_dotenv
import json
import mimetypes

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
site_folder = BASE_DIR / '../site'


#########################################################
# ETAPE 1: Créer le bucket
#########################################################
def create_bucket(bucket_name, region):

    print("\n🚀 Création du bucket S3...")
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


#########################################################
# ETAPE 2: Désactiver le blocage public
#########################################################
def disable_public_block(bucket_name):

    print("\n🔓 Désactivation du blocage public...")
    print("-------------------------------------")

    s3 = boto3.client('s3')
    s3.put_public_access_block(
        Bucket=bucket_name,
        PublicAccessBlockConfiguration={
            'BlockPublicAcls': False,
            'IgnorePublicAcls': False,
            'BlockPublicPolicy': False,
            'RestrictPublicBuckets': False
        }
    )
    print("  ✅ Blocage public désactivé")


#########################################################
# ETAPE 3: Ajouter la policy publique
#########################################################
def add_bucket_policy(bucket_name):

    print("\n📜 Ajout de la policy publique...")
    print("-------------------------------------")

    policy = {
        'Version': '2012-10-17',
        'Statement': [{
            'Sid': 'AddPerm',
            'Effect': 'Allow',
            'Principal': '*',
            'Action': ['s3:GetObject'],
            'Resource': f'arn:aws:s3:::{bucket_name}/*'
        }]
    }

    # Appliquer la nouvelle policy
    s3 = boto3.client('s3')
    s3.put_bucket_policy(Bucket=bucket_name, Policy=json.dumps(policy))

    print("  ✅ Policy appliquée")

#########################################################
# ETAPE 4: Upload du site
#########################################################
def upload_site(site_folder, bucket_name):

    print("\n📤 Upload du contenu du site...")
    print("-------------------------------------")

    s3_client = boto3.client('s3')
    for root, dirs, files in os.walk(site_folder):
        for file in files:
            file_path = Path(root) / file
            object_name = str(file_path.relative_to(site_folder))

            content_type, _ = mimetypes.guess_type(file_path)
            if content_type is None:
                content_type = "binary/octet-stream"

            try:
                s3_client.upload_file(
                    str(file_path),
                    bucket_name,
                    object_name,
                    ExtraArgs={"ContentType": content_type}
                )
                print(f"  ✅ {object_name} uploadé avec Content-Type: {content_type}")
            except ClientError as e:
                print(f"❌ Erreur lors de l'envoi du fichier {object_name} : {e}")
                

#########################################################
# ETAPE 5: Activer le mode site web
#########################################################
def enable_website(bucket_name):

    print("\n🌐 Activation du mode site web...")
    print("-------------------------------------")

    # Définir la configuration du site web
    config = {'IndexDocument': {'Suffix': 'index.html'}}

    # Appliquer la configuration du site web
    s3 = boto3.client('s3')
    s3.put_bucket_website(Bucket=bucket_name, WebsiteConfiguration=config)

    print(f"  ✅ Site web activé pour {bucket_name}")


#########################################################
# EXECUTION DES FONCTIONS
#########################################################
if __name__ == "__main__":
    create_bucket(aws_bucket_name, aws_region)
    disable_public_block(aws_bucket_name)
    add_bucket_policy(aws_bucket_name)
    upload_site(site_folder, aws_bucket_name)
    enable_website(aws_bucket_name)

    print("\n🏁 Déploiement terminé !")
    print(f"🔗 URL du site : http://{aws_bucket_name}.s3-website.{aws_region}.amazonaws.com")