"""
Lambda 1 — validate-order
Receives a JSON order, validates required fields and their consistency.
Returns the enriched order if valid, otherwise raises an exception.
"""

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

REQUIRED_FIELDS = ["order_id", "customer_id", "product_id", "quantity", "amount"]


def lambda_handler(event, context):
    logger.info(f"Validating order: {json.dumps(event)}")

    errors = []

    # Required fields validation
    for field in REQUIRED_FIELDS:
        if field not in event:
            errors.append(f"Missing required field: '{field}'")

    if errors:
        raise ValueError(f"ValidationError: {'; '.join(errors)}")

    # Value consistency validation
    quantity = event.get("quantity")
    amount = event.get("amount")

    if not isinstance(quantity, int) or quantity <= 0:
        raise ValueError("ValidationError: 'quantity' must be a positive integer")

    if not isinstance(amount, (int, float)) or amount <= 0:
        raise ValueError("ValidationError: 'amount' must be a positive number")

    if len(str(event.get("order_id", ""))) == 0:
        raise ValueError("ValidationError: 'order_id' cannot be empty")

    if len(str(event.get("customer_id", ""))) == 0:
        raise ValueError("ValidationError: 'customer_id' cannot be empty")

    logger.info(f"Order {event['order_id']} validated successfully")

    # Return enriched order
    return {
        **event,
        "validation_status": "success",
        "validated_at": context.aws_request_id,
    }