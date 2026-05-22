#!/usr/bin/env bash
# 3-redeploy.sh — Force a new ECS deployment and display the task URL
#
# Prerequisite: run 1-infra.sh and 2-push.sh
# Usage       : ./scripts/3-redeploy.sh

set -e

# Fetch values from Terraform outputs
cd "$(dirname "$0")/../terraform"

CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
AWS_REGION=$(terraform output -raw aws_region)

echo "=== Force new deployment ==="
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service  "$SERVICE" \
  --force-new-deployment \
  --region   "$AWS_REGION" \
  --output json | python3 -c "
import sys, json
d = json.load(sys.stdin)['service']['deployments'][0]
print(f\"  status        : {d['status']}\")
print(f\"  desiredCount  : {d['desiredCount']}\")
print(f\"  runningCount  : {d['runningCount']}\")
"

echo ""
echo "=== Wait for the service to become stable ==="
echo "(may take 1-2 minutes)"
aws ecs wait services-stable \
  --cluster  "$CLUSTER" \
  --services "$SERVICE" \
  --region   "$AWS_REGION"

echo ""
echo "=== Fetching the public IP ==="

TASK_ARN=$(aws ecs list-tasks \
  --cluster      "$CLUSTER" \
  --service-name "$SERVICE" \
  --region       "$AWS_REGION" \
  --query        'taskArns[0]' \
  --output text)

ENI_ID=$(aws ecs describe-tasks \
  --cluster "$CLUSTER" \
  --tasks   "$TASK_ARN" \
  --region  "$AWS_REGION" \
  --query   'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output  text)

PUBLIC_IP=$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --region                "$AWS_REGION" \
  --query                 'NetworkInterfaces[0].Association.PublicIp' \
  --output                text)

echo ""
echo "Application accessible at:"
echo "  http://$PUBLIC_IP:5000/"
echo "  http://$PUBLIC_IP:5000/health"
echo ""
echo "Quick test:"
echo "  curl http://$PUBLIC_IP:5000/"