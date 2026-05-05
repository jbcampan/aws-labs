import boto3
import json
import os
from botocore.exceptions import ClientError

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

def handler(event, context):
    # 1. Retrieve path parameters
    path_params = event.get("pathParameters") or {}
    item_id = path_params.get("id")

    if not item_id:
        return response(400, {"error": "id missing"})

    try:
        # 2. Try to delete the item
        # The condition fails if the item does not exist.
        table.delete_item(
            Key={"id": item_id},
            ConditionExpression="attribute_exists(id)"
        )

    except ClientError as error:
        error_code = error.response["Error"]["Code"]

        # 3. Case if item doesn't exists
        if error_code == "ConditionalCheckFailedException":
            return response(404, {"error": "not found"})

        # 4. Other AWS errors → let them propagate
        raise

    # 5. Success
    return response(200, {"message": f"item {item_id} supprimé"})


def response(status_code: int, body: dict) -> dict:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
        },
        "body": json.dumps(body),
    }