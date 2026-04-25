import json
import os
import subprocess
import uuid
from datetime import datetime, timezone

import boto3


REGION = "eu-west-3"

sqs = boto3.client("sqs", region_name=REGION)


# ─── Retrieving the queue URL ───────────────────

def get_queue_url() -> str:
    """
    Retrieves the SQS queue URL from Terraform outputs.
    We move into the terraform/ directory relative to this script.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    terraform_dir = os.path.join(script_dir, "..", "terraform")

    result = subprocess.run(
        ["terraform", "output", "-raw", "main_queue_url"],
        cwd=terraform_dir,
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError(
            f"Could not get Terraform output:\n{result.stderr}"
        )

    return result.stdout.strip()


# ─── Message ─────────────────────────────────────────────

def build_message(i: int) -> dict:
    return {
        "message_id": str(uuid.uuid4()),
        "index": i,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "payload": {
            "user_id": f"user_{i:04d}",
            "action": "order_placed",
            "amount": 10 + i * 2,
        },
    }


# ─── Batch send ──────────────────────────────────────────

def send_batch(queue_url: str, messages: list[dict]):
    entries = [
        {
            "Id": str(i),
            "MessageBody": json.dumps(msg),
        }
        for i, msg in enumerate(messages)
    ]

    response = sqs.send_message_batch(
        QueueUrl=queue_url,
        Entries=entries,
    )

    print(f"  Sent: {len(response.get('Successful', []))}")
    print(f"  Failed: {len(response.get('Failed', []))}")


# ─── Main ────────────────────────────────────────────────

def main():
    print("Fetching queue URL from Terraform...")
    queue_url = get_queue_url()
    print(f"Queue URL: {queue_url}\n")

    messages = [build_message(i) for i in range(15)]

    batch_size = 10
    for i in range(0, len(messages), batch_size):
        batch = messages[i:i + batch_size]
        batch_end = i + len(batch)
        print(f"Sending messages {i + 1}–{batch_end}...")
        send_batch(queue_url, batch)


if __name__ == "__main__":
    main()