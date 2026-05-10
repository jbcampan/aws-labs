import boto3

TABLE_NAME = "lab-01-scheduled-rule-items"      # Variables to adapt depending on your configuration
AWS_REGION = "eu-west-3"                        # before using this file to populate the table
 
dynamodb = boto3.resource("dynamodb", region_name=AWS_REGION)
table = dynamodb.Table(TABLE_NAME)
 
items = [
    {"id": "1", "name": "Alice",   "status": "active",   "score": 42},
    {"id": "2", "name": "Bob",     "status": "inactive", "score": 17},
    {"id": "3", "name": "Charlie", "status": "active",   "score": 88},
]
 
for item in items:
    table.put_item(Item=item)
    print(f"Inséré : {item}")
 
print("Seed finished.")
 