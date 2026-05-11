import boto3
import json
import os

sns = boto3.client("sns")
TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]

def handler(event, context):
    print(json.dumps(event))  # CloudWatch logs, essential for viewing the raw event.

    instance_id = event["detail"]["instance-id"]
    state = event["detail"]["state"]

    message = f"""
EC2 Instance Alert

Instance ID: {instance_id}
New State: {state}
"""

    sns.publish(
        TopicArn=TOPIC_ARN,
        Subject="EC2 State Change Alert",
        Message=message
    )

    return {
        "statusCode": 200,
        "body": json.dumps("Notification sent")
    }