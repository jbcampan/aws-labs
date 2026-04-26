import boto3
import csv
import json
import os
import urllib.parse

s3 = boto3.client("s3")

DEST_BUCKET = os.environ["DEST_BUCKET"]


def lambda_handler(event, context):

    # 1. Extract information from the S3 event
    record = event["Records"][0]
    source_bucket = record["s3"]["bucket"]["name"]
    object_key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

    print(f"File received : {object_key} from {source_bucket}")

    # 2. Read the CSV file from S3
    response = s3.get_object(Bucket=source_bucket, Key=object_key)
    content = response["Body"].read().decode("utf-8")

    reader = csv.DictReader(content.splitlines())

    result = []

    # 3. Transform the data
    for row in reader:

        # Filter inactive rows
        if row["active"].lower() == "false":
            continue

        new_row = {
            "id": row["id"],
            "name": row["name"].title(),
            "amount": float(row["amount"]),
            "active": True,
            "source_file": object_key
        }

        result.append(new_row)

    # 4. Create the JSON file
    json_data = json.dumps(result, indent=2, ensure_ascii=False)

    # 5. Define the output filename
    # "uploads/sample.csv" → "processed/sample.json"
    output_key = object_key.replace("uploads/", "processed/").replace(".csv", ".json")

    # 6. Write to the destination bucket
    s3.put_object(
        Bucket=DEST_BUCKET,
        Key=output_key,
        Body=json_data,
        ContentType="application/json"
    )

    print(f"Transformed file written to {DEST_BUCKET}/{output_key}")

    return {
        "statusCode": 200,
        "body": "OK"
    }