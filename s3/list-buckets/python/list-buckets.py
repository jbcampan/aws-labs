import boto3

# Retourner la liste des buckets existants
s3 = boto3.client('s3')
response = s3.list_buckets()

# Afficher les noms des buckets
print('🪣   Buckets existants:')
print("-------------------------------------")
for bucket in response['Buckets']:
    print(f'  {bucket["Name"]}')