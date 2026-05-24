#!/usr/bin/env bash
# observe.sh — Watch the ALB responses and ECS task counts in real time
#
# Run this in a dedicated terminal while using the app or running load_test.sh.
# Each line shows:
#   - which task responded (hostname changes = load balancing is working)
#   - how many tasks are desired / running / pending
set -e

# ── Read Terraform outputs ────────────────────────────────────────────────────

cd ../terraform
ALB_URL=$(terraform output -raw alb_dns_name)
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
REGION=$(terraform output -raw aws_region)
cd ../script

echo "👀 Observing lab-02 — Ctrl+C to stop"
echo "   ALB: $ALB_URL"
echo ""
printf "%-6s %-40s %s\n" "REQ" "HOSTNAME (task that responded)" "TASKS (desired/running/pending)"
echo "────────────────────────────────────────────────────────────────────────"

count=0

while true; do
  count=$((count + 1))

  # ── Call the ALB and extract the hostname from the JSON response ──────────
  #
  # The app returns: {"hostname": "ip-10-0-2-45", "message": "...", ...}
  # python3 -c parses the JSON inline — no extra tools needed.

  RESPONSE=$(curl -s --max-time 3 "$ALB_URL" 2>/dev/null || echo '{"hostname":"ERROR"}')
  HOSTNAME=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('hostname','?'))" 2>/dev/null || echo "?")

  # ── Query ECS for current task counts ────────────────────────────────────

  DESIRED=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].desiredCount' --output text 2>/dev/null || echo "?")
  RUNNING=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].runningCount' --output text 2>/dev/null || echo "?")
  PENDING=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].pendingCount' --output text 2>/dev/null || echo "?")

  printf "%-6s %-40s desired=%-3s running=%-3s pending=%s\n" \
    "#$count" "$HOSTNAME" "$DESIRED" "$RUNNING" "$PENDING"

  sleep 3
done
