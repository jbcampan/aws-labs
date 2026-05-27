"""
Lambda 4 — send-confirmation
Publishes a confirmation message to an SNS topic.
Used in the Parallel branch: customer email confirmation.
"""

import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns = boto3.client("sns")

CONFIRMATION_TOPIC_ARN = os.environ["CONFIRMATION_TOPIC_ARN"]


def lambda_handler(event, context):
    order_id = event.get("order_id")
    customer_id = event.get("customer_id")
    transaction_id = event.get("transaction_id", "N/A")
    amount = event.get("amount_charged", event.get("amount", 0))

    logger.info(f"Sending confirmation for order {order_id} to customer {customer_id}")

    message = {
        "type": "ORDER_CONFIRMATION",
        "order_id": order_id,
        "customer_id": customer_id,
        "transaction_id": transaction_id,
        "amount_charged": amount,
        "message": (
            f"Your order {order_id} has been confirmed! "
            f"Transaction ID: {transaction_id}. "
            f"Amount charged: ${amount:.2f}."
        ),
    }

    response = sns.publish(
        TopicArn=CONFIRMATION_TOPIC_ARN,
        Message=json.dumps(message),
        Subject=f"Order Confirmation - {order_id}",
        MessageAttributes={
            "event_type": {
                "DataType": "String",
                "StringValue": "ORDER_CONFIRMATION",
            }
        },
    )

    logger.info(f"Confirmation published, MessageId: {response['MessageId']}")

    return {
        "confirmation_sent": True,
        "message_id": response["MessageId"],
        "order_id": order_id,
        "customer_id": customer_id,
    }