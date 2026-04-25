import boto3
import os
import json

# Get the SQS queue URL from an environment variable
# (must be set beforehand, e.g., export SQS_QUEUE_URL=...)
queue_url = os.environ["SQS_QUEUE_URL"]

# Create an SQS client using default AWS credentials/config
sqs = boto3.client("sqs")

# Receive up to 1 message from the queue
response = sqs.receive_message(
    QueueUrl=queue_url,
    MaxNumberOfMessages=1
)

# Extract messages safely (empty list if none returned)
messages = response.get("Messages", [])

if not messages:
    print("No messages")
else:
    msg = messages[0]

    # Print the raw message body (as stored in SQS)
    print("Raw message:")
    print(msg["Body"])

    # SNS wraps the original message in JSON → decode it
    body = json.loads(msg["Body"])

    # Extract and print the actual SNS message content
    print("\nSNS message:")
    print(body["Message"])