import boto3
import os

# Get the SNS Topic ARN from an environment variable
# (must be set beforehand, e.g., export SNS_TOPIC_ARN=...)
topic_arn = os.environ["SNS_TOPIC_ARN"]

# Create an SNS client using default AWS credentials/config
sns = boto3.client("sns")

# Publish a simple message to the SNS topic
response = sns.publish(
    TopicArn=topic_arn,          # Target SNS topic
    Subject="Test SNS",          # Email subject (used for email subscriptions)
    Message="Hello from my first SNS message!"  # Message body
)

# Print the unique message ID returned by AWS
print("Message sent! ID:", response["MessageId"])