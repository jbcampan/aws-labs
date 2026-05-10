import json
import logging
import os
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ["TABLE_NAME"]

dynamodb = boto3.resource("dynamodb")


def lambda_handler(event, context):

    logger.info("Lambda triggered by EventBridge")

    try:
        table = dynamodb.Table(TABLE_NAME)

        response = table.scan()
        items = response.get("Items", [])

        item_count = len(items)
        sample_item = items[0] if items else None

        report = {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "table_name": TABLE_NAME,
            "item_count": item_count,
            "sample_item": sample_item,
        }

        logger.info(json.dumps(report, default=str))

        return {
            "statusCode": 200,
            "body": json.dumps(report, default=str),
        }

    except ClientError as error:
        logger.error(f"Error DynamoDB : {error}")

        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Error DynamoDB"}),
        }