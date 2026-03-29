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


def delete_bucket(bucket_name, region):

    """Supprimer un bucket S3 dans une région spécifiée"""

    print("")  # ligne vide de séparation
    print(f"🪣 Traitement du bucket '{bucket_name}'")
    print("-------------------------------------")

    try:
        s3_client = boto3.client('s3', region_name=region)
        
        #Vider le contenu du bucket
        print("  🗑️  Suppression du contenu…")
        try:
            response = s3_client.list_objects_v2(Bucket=bucket_name)
            if 'Contents' in response:
                for obj in response['Contents']:
                    s3_client.delete_object(Bucket=bucket_name, Key=obj['Key'])
                print(f"    ✅ Contenu supprimé")
            else:
                print(f"    ✅  Le bucket est déjà vide")
        except ClientError as e:
            print(f"    ❌ Erreur lors de la suppression du contenu : {e}")
            return False

        #Supprimer le bucket
        print("  🗑️  Suppression du bucket…")
        s3_client.delete_bucket(Bucket=bucket_name)
        print(f"    ✅ Bucket '{bucket_name}' supprimé avec succès !")
        return True

    except ClientError as e:
        print(f"    ❌ Erreur lors de la suppression du bucket : {e}")
        return False

if __name__ == "__main__":
    delete_bucket(aws_bucket_name,aws_region)

print("")
print("🏁 Terminé.")