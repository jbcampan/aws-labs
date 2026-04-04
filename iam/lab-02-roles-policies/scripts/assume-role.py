# Étape 1 : Initialisation du client STS
# ----------------------------------------
# On initialise un client pour le service STS (Security Token Service), 
# qui permet d'obtenir des credentials temporaires pour assumer un rôle IAM.

# Étape 2 : Appel AssumeRole
# ---------------------------
# On utilise le client STS pour appeler la méthode `assume_role` et demander à AWS 
# de nous fournir des credentials temporaires pour assumer un rôle IAM spécifique.
# L'ARN du rôle et un nom de session unique sont fournis pour identifier cette session.

# Étape 3 : Récupération des credentials temporaires
# ---------------------------------------------------
# AWS renvoie un ensemble de credentials temporaires, incluant un 
# `AccessKeyId`, `SecretAccessKey` et `SessionToken`, que nous utiliserons 
# pour accéder à d'autres ressources AWS avec les permissions associées au rôle.

# Étape 4 : Création d'un client S3 avec les credentials temporaires
# -------------------------------------------------------------------
# On crée un client S3 en utilisant les credentials temporaires obtenus via `assume_role`.
# Cela permet d'interagir avec S3 en utilisant les permissions du rôle assumé, 
# et non celles du user IAM d'origine.

# Étape 5 : Accès au bucket S3
# ----------------------------
# On utilise le client S3 pour effectuer des opérations sur un bucket S3 
# (par exemple, lister les objets dans le bucket).
# Cette opération est effectuée avec les permissions du rôle temporaire.

# Étape 6 : Affichage des objets dans le bucket S3
# -------------------------------------------------
# Si les permissions sont valides et suffisantes, on parcourt et affiche 
# les clés des objets présents dans le bucket spécifié.


import boto3
import os

# Récupération des variables d'environnement passées par le bash
role_arn = os.environ["ROLE_ARN"]
bucket_name = os.environ["BUCKET_NAME"]

# Étape 1 : Initialisation du client STS
sts_client = boto3.client("sts")

# Étape 2 : Appel AssumeRole
print("Appel AssumeRole en cours...")
response = sts_client.assume_role(
    RoleArn=role_arn,           # ARN du rôle IAM
    RoleSessionName="mysession" # Nom arbitraire pour identifier la session
)
# Affichage de la réponse complète d'AssumeRole
print("Réponse de assume_role:", response)

# Étape 3 : Récupération des credentials temporaires
credentials = response["Credentials"]
print(f"AccessKeyId     : {credentials['AccessKeyId']}")
print(f"SecretAccessKey : {credentials['SecretAccessKey']}")
print(f"SessionToken    : {credentials['SessionToken']}")

# Étape 4 : Création du client S3 avec les credentials temporaires
s3_client = boto3.client(
    "s3",
    aws_access_key_id=credentials["AccessKeyId"],
    aws_secret_access_key=credentials["SecretAccessKey"],
    aws_session_token=credentials["SessionToken"],
)

# Étape 5 : Lister les objets du bucket
print(f"\nRécupération des objets dans le bucket '{bucket_name}'...")
s3_response = s3_client.list_objects_v2(Bucket=bucket_name)

# Affichage de la réponse de l'appel S3
print("Réponse de S3:", s3_response)

# Étape 6 : Affichage
if "Contents" in s3_response:
    print("Liste des objets :")
    for obj in s3_response["Contents"]:
        print(f"  - {obj['Key']}")
else:
    print("Aucun objet trouvé dans le bucket.")