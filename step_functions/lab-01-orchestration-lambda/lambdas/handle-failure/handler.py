"""
Lambda 5 — handle-failure
Invoked only when the workflow fails globally.
- Logs structured error details
- Publishes an alert to the SNS alerts topic
- Triggered from two paths: Choice state (out-of-stock) and Catch (payment failure)
"""

import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns = boto3.client("sns")

ALERT_TOPIC_ARN = os.environ["ALERT_TOPIC_ARN"]


def lambda_handler(event, context):
    # Step Functions injects Cause and Error when using Catch
    error = event.get("Error", "UnknownError")
    cause = event.get("Cause", "No cause provided")
    order_id = event.get("order_id", "UNKNOWN")
    inventory_status = event.get("inventory_status", "N/A")

    # Determine failure type for structured logging
    if inventory_status == "out-of-stock":
        failure_reason = "OUT_OF_STOCK"
        failure_message = f"Order {order_id} failed: product out of stock"
    else:
        failure_reason = "PAYMENT_FAILED"
        failure_message = f"Order {order_id} failed: payment processing error after retries"

    logger.error(
        json.dumps({
            "level": "ERROR",
            "failure_reason": failure_reason,
            "order_id": order_id,
            "error": error,
            "cause": cause,
            "inventory_status": inventory_status,
            "original_event": event,
        })
    )

    # Publish alert to SNS
    alert_message = {
        "type": "ORDER_FAILURE_ALERT",
        "failure_reason": failure_reason,
        "order_id": order_id,
        "error": error,
        "cause": cause,
        "message": failure_message,
    }

    response = sns.publish(
        TopicArn=ALERT_TOPIC_ARN,
        Message=json.dumps(alert_message),
        Subject=f"ALERT: Order Failed - {order_id}",
        MessageAttributes={
            "event_type": {
                "DataType": "String",
                "StringValue": "ORDER_FAILURE_ALERT",
            },
            "failure_reason": {
                "DataType": "String",
                "StringValue": failure_reason,
            },
        },
    )

    logger.info(f"Alert published, MessageId: {response['MessageId']}")

    return {
        "failure_handled": True,
        "failure_reason": failure_reason,
        "order_id": order_id,
        "alert_message_id": response["MessageId"],
    }