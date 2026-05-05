import boto3
import json
import os
from botocore.exceptions import ClientError
from decimal import Decimal

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def decimal_to_native(obj):
    if isinstance(obj, list):
        return [decimal_to_native(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: decimal_to_native(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj


def handler(event, context):
    # 1. Retrieve id from path
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    if not item_id:
        return response(400, {"error": "id missing"})

    # 2. Read and parse the body
    raw_body = event.get("body") or "{}"

    try:
        body = json.loads(raw_body)
    except json.JSONDecodeError:
        return response(400, {"error": "invalid body format (json expected)"})

    # Primary key can't be modified
    body.pop("id", None)

    if not body:
        return response(400, {"error": "body empty"})

    # 3. Dynamically build the update expression
    # enumerate(body.items()) gives us (index, (key, value)) — no manual counter needed
    update_parts = []
    expr_names = {}
    expr_values = {}

    for i, (key, value) in enumerate(body.items()):
        name_key = f"#n{i}"
        value_key = f":v{i}"
        update_parts.append(f"{name_key} = {value_key}")
        expr_names[name_key] = key
        expr_values[value_key] = value

    update_expression = "SET " + ", ".join(update_parts)

    # 4. Update in DynamoDB
    try:
        result = table.update_item(
            Key={"id": item_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expr_names,
            ExpressionAttributeValues=expr_values,
            ConditionExpression="attribute_exists(id)",
            ReturnValues="ALL_NEW"
        )

    except ClientError as error:
        if error.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return response(404, {"error": "not found"})
        raise

    # 5. Return updated item
    return response(200, result["Attributes"])


def response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(decimal_to_native(body)),
    }