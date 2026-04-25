import json
import os
import random


FAILURE_RATE = float(os.environ.get("FAILURE_RATE", "0.4"))


def lambda_handler(event, context):
    print(f"Received {len(event['Records'])} messages")

    failed = []

    for record in event["Records"]:
        message_id = record["messageId"]
        body = record["body"]

        print(f"\nProcessing message {message_id}")

        try:
            payload = json.loads(body)
            print(f"Payload: {payload}")
        except (json.JSONDecodeError, TypeError):
            print(f"Raw body: {body}")

        # Failure simulation
        if random.random() < FAILURE_RATE:
            print(f"❌ Message {message_id} failed")
            failed.append(message_id)
        else:
            print(f"✅ Message {message_id} processed")

    # Very important: tell AWS which messages failed
    return {
        "batchItemFailures": [
            {"itemIdentifier": mid} for mid in failed
        ]
    }