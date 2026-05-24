#!/usr/bin/env bash
# load_test.sh — Send sustained traffic to the ALB to trigger ECS auto scaling
#
# How it works:
#   Bash's & operator runs a command in the background.
#   We launch N workers in parallel, each sending requests in a loop.
#   More workers = more concurrent requests = more CPU on the Flask tasks.
#
# Usage:
#   ./load_test.sh            → 10 workers for 3 minutes (default)
#   ./load_test.sh 20         → 20 workers for 3 minutes
#   ./load_test.sh 20 600     → 20 workers for 10 minutes
set -e

# ── Config ────────────────────────────────────────────────────────────────────

cd ../terraform
ALB_URL=$(terraform output -raw alb_dns_name)
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
REGION=$(terraform output -raw aws_region)
cd ../script

WORKERS=${1:-10}    # number of parallel curl loops
DURATION=${2:-180}  # total duration in seconds

# ── Start ─────────────────────────────────────────────────────────────────────

echo "🔥 Load test starting"
echo "   URL      : $ALB_URL"
echo "   Workers  : $WORKERS parallel loops"
echo "   Duration : ${DURATION}s"
echo ""
echo "   In another terminal, run: ./scripts/observe.sh"
echo "   You should see desiredCount increase after ~2 min (CPU alarm threshold)"
echo ""

# Each worker runs a curl loop for DURATION seconds, then exits.
# Output is suppressed (> /dev/null 2>&1) to keep the terminal readable.
worker() {
  local end=$((SECONDS + DURATION))
  while [ $SECONDS -lt $end ]; do
    curl -s "$ALB_URL" > /dev/null 2>&1
  done
}

# Launch all workers in the background
for i in $(seq 1 "$WORKERS"); do
  worker &
done

# Print task counts every 15 seconds while workers are running
elapsed=0
while [ $elapsed -lt "$DURATION" ]; do
  sleep 15
  elapsed=$((elapsed + 15))

  DESIRED=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].desiredCount' --output text 2>/dev/null || echo "?")
  RUNNING=$(aws ecs describe-services \
    --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].runningCount' --output text 2>/dev/null || echo "?")

  echo "   [${elapsed}s] tasks → desired: $DESIRED  running: $RUNNING"
done

# Wait for all background workers to finish
wait

echo ""
echo "✅ Load test finished"
echo "   Scale-in (CPU < 20%) will trigger after ~2-3 min of inactivity"
echo "   Keep observe.sh running to watch tasks being removed"
