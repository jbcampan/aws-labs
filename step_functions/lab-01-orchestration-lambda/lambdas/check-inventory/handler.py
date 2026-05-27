"""
Lambda 2 — check-inventory
Simulates a stock check.
- Returns "in-stock" ~70% of the time
- Returns "out-of-stock" ~30% of the time
- Some product_id values force deterministic results for testing
"""

import json
import logging
import random

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Deterministic product IDs for reproducible tests
ALWAYS_IN_STOCK = {"PROD-001", "PROD-002", "PROD-999"}
ALWAYS_OUT_OF_STOCK = {"PROD-OUT", "PROD-000"}


def lambda_handler(event, context):
    logger.info(f"Checking inventory for order: {event.get('order_id')}")

    product_id = event.get("product_id", "")
    quantity = event.get("quantity", 1)

    # Deterministic logic for tests
    if product_id in ALWAYS_IN_STOCK:
        stock_status = "in-stock"
        available_quantity = quantity + 10
    elif product_id in ALWAYS_OUT_OF_STOCK:
        stock_status = "out-of-stock"
        available_quantity = 0
    else:
        # Random simulation: 70% in-stock, 30% out-of-stock
        if random.random() < 0.7:
            stock_status = "in-stock"
            available_quantity = quantity + random.randint(0, 50)
        else:
            stock_status = "out-of-stock"
            available_quantity = 0

    logger.info(
        f"Product {product_id}: {stock_status} (requested: {quantity}, available: {available_quantity})"
    )

    return {
        **event,
        "inventory_status": stock_status,
        "available_quantity": available_quantity,
    }