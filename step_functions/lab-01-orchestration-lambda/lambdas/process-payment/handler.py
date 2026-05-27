"""
Lambda 3 — process-payment
Simulates payment processing.
- Intentionally fails on certain amounts to test retries
- Amounts >= 1000: always fail (simulates bank rejection)
- Amounts between 500 and 999: 60% random failure (simulates instability)
- Amounts < 500: guaranteed success

Designed to demonstrate Step Functions exponential backoff retry behavior.
"""

import json
import logging
import random
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class PaymentDeclinedException(Exception):
    """Raised when payment is declined — will trigger retries."""
    pass


class PaymentGatewayException(Exception):
    """Raised to simulate transient gateway failures."""
    pass


def lambda_handler(event, context):
    order_id = event.get("order_id")
    amount = event.get("amount", 0)

    logger.info(f"Processing payment for order {order_id}, amount: {amount}")

    # Simulated payment gateway latency
    time.sleep(0.1)

    if amount >= 1000:
        # Permanent failure — all retries will fail, triggering Catch
        logger.error(f"Payment DECLINED for order {order_id}: amount {amount} exceeds limit")
        raise PaymentDeclinedException(
            f"Payment declined: amount {amount} exceeds maximum allowed (999)"
        )

    if 500 <= amount < 1000:
        # Random failure — allows testing retry success after multiple attempts
        if random.random() < 0.6:
            logger.warning(f"Payment gateway timeout for order {order_id}, will retry")
            raise PaymentGatewayException(
                f"Payment gateway timeout: transient error for order {order_id}"
            )

    # Success case
    transaction_id = f"TXN-{order_id}-{int(time.time())}"
    logger.info(f"Payment SUCCESS for order {order_id}: transaction {transaction_id}")

    return {
        **event,
        "payment_status": "success",
        "transaction_id": transaction_id,
        "amount_charged": amount,
    }