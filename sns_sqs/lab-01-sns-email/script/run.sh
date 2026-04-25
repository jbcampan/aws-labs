#!/bin/bash
set -euo pipefail

# Resolve the absolute path of the directory containing this script.
# This ensures the script works regardless of where it's called from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Move to the Terraform directory to run output commands
cd "$SCRIPT_DIR/../terraform"

# Retrieve infrastructure values from Terraform outputs
# and expose them as environment variables for the Python scripts
export SNS_TOPIC_ARN=$(terraform output -raw sns_topic_arn)
export SQS_QUEUE_URL=$(terraform output -raw sqs_queue_url)

# Move back to the script directory where the Python files live
cd "$SCRIPT_DIR"

# Route to the correct Python script based on the first argument passed
case "${1:-}" in
  publish)  python publish.py ;;   # Publish a message to the SNS topic
  read)     python read_sqs.py ;;  # Read a message from the SQS queue
  *)        echo "Usage: ./run.sh [publish|read]" && exit 1 ;;  # Unknown argument
esac