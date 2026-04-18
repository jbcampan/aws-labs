#!/bin/bash
# =============================================================
# stress-test.sh - generates load to test alarms
# Usage : ./stress-test.sh [cpu|ram|disk] [duration in seconds]
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "$SCRIPT_DIR/../terraform" && pwd)"

INSTANCE_ID=$(terraform -chdir="$TF_DIR" output -raw instance_id)
REGION=$(terraform -chdir="$TF_DIR" output -raw aws_region)

if [[ -z "$INSTANCE_ID" || -z "$REGION" ]]; then
  echo "❌ Terraform outputs are empty"
  exit 1
fi

DURATION=${2:-120}

echo "🖥️  Instance : $INSTANCE_ID"
echo "⏱️  Duration    : ${DURATION}s"
echo "🎯  Mode     : ${1:-cpu}"
echo ""

case "${1:-cpu}" in
  cpu)
    echo "🔥 CPU load generation (goal: trigger the 80% alarm)..."
    COMMAND="stress-ng --cpu \$(nproc) --timeout ${DURATION}s || (dnf install -y stress-ng && stress-ng --cpu \$(nproc) --timeout ${DURATION}s)"
    ;;
  ram)
    echo "🧠 Filling RAM memory..."
    COMMAND="stress-ng --vm 2 --vm-bytes 80% --timeout ${DURATION}s || (dnf install -y stress-ng && stress-ng --vm 2 --vm-bytes 80% --timeout ${DURATION}s)"
    ;;
  disk)
    echo "💾 Disk I/O load..."
    COMMAND="dd if=/dev/zero of=/tmp/testfile bs=1M count=500 oflag=dsync && rm /tmp/testfile"
    ;;
  *)
    echo "Usage : $0 [cpu|ram|disk] [duration]"
    exit 1
    ;;
esac

echo "📡 Sending command via SSM..."
COMMAND_ID=$(aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters "commands=[\"$COMMAND\"]" \
  --region "$REGION" \
  --query "Command.CommandId" \
  --output text)

echo "✅ Command started : $COMMAND_ID"
echo ""
echo "📊 Monitor the dashboard :"
echo "   https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#dashboards:name=lab02-metrics-dashboard"
echo ""
echo "🔍 Check the command status :"
echo "   aws ssm get-command-invocation --command-id $COMMAND_ID --instance-id $INSTANCE_ID --region $REGION"
