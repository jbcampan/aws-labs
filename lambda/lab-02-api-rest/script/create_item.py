import boto3
import json
import os
import uuid

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    # 1. Retrieve and parse the body (string JSON -> dict)
    raw_body = event.get("body") or "{}"

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return response(400, {"error": "invalid body format (json expected)"})

    # Verify that the body is not empty
    if not body:
        return response(400, {"error": "empty body"})

    # 2. Generate unic ids
    item_id = str(uuid.uuid4())

    # 3. Build item to insert
    item = {
        "id": item_id
    }

    # Add fields to the body one by one
    for key, value in body.items():
        item[key] = value

    # 4. Insert in DynamoDB
    table.put_item(Item=item)

    # 5. Return response
    return response(201, item)


def response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }