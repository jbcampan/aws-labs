import boto3
import json
import os
from decimal import Decimal

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def decimal_to_native(obj):
    if isinstance(obj, list):
        return [decimal_to_native(i) for i in obj]
    elif isinstance(obj, dict):
        return {k: decimal_to_native(v) for k, v in obj.items()}
    elif isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj



def handler(event, context):
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    if not item_id:
        return response(400, {"error": "id missing"})

    result = table.get_item(
        Key={"id": item_id},
        ConsistentRead=True
    )

    item = result.get("Item")
    if not item:
        return response(404, {"error": "not found"})

    return response(200, item)


def response(status, body):
    return {
        "statusCode": status,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(decimal_to_native(body)),
    }