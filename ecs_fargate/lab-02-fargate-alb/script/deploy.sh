#!/usr/bin/env bash
# deploy.sh — Build the Docker image, push it to ECR, and redeploy the ECS service
set -e

# ── 1. Read Terraform outputs ─────────────────────────────────────────────────

echo "📦 Reading Terraform outputs..."
cd ../terraform

ECR_URL=$(terraform output -raw ecr_repository_url)
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
ALB_URL=$(terraform output -raw alb_dns_name)
REGION=$(terraform output -raw aws_region)

cd ../script

echo "  ECR     : $ECR_URL"
echo "  Cluster : $CLUSTER"
echo "  Service : $SERVICE"
echo "  ALB     : $ALB_URL"
echo ""

# ── 2. Authenticate Docker with ECR ──────────────────────────────────────────

echo "🔑 Logging into ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR_URL"
echo ""

# ── 3. Build the image ────────────────────────────────────────────────────────
#
# --platform linux/amd64 is required when building on a Mac M1/M2/M3 (ARM).
# Without it, the image would be ARM64 and crash on Fargate (x86_64).

echo "🐳 Building Docker image..."
docker build --platform linux/amd64 -t flask-app ../app
echo ""

# ── 4. Tag and push ───────────────────────────────────────────────────────────

echo "🏷️  Tagging image..."
docker tag flask-app:latest "$ECR_URL:latest"

echo "⬆️  Pushing image to ECR..."
docker push "$ECR_URL:latest"
echo ""

# ── 5. Force ECS to redeploy with the new image ───────────────────────────────
#
# ECS performs a rolling update:
#   - starts new tasks with the new image
#   - waits for them to pass health checks
#   - then stops the old tasks
# No downtime, controlled by deployment_minimum_healthy_percent in ecs.tf.

echo "🚀 Triggering ECS rolling update..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service  "$SERVICE" \
  --force-new-deployment \
  --region   "$REGION" \
  --output json > /dev/null

echo "⏳ Waiting for service to stabilize (can take 2-3 min)..."
aws ecs wait services-stable \
  --cluster  "$CLUSTER" \
  --services "$SERVICE" \
  --region   "$REGION"

# ── 6. Done ───────────────────────────────────────────────────────────────────

echo ""
echo "✅ Deployment complete!"
echo ""
echo "   Test your app:"
echo "   curl $ALB_URL"
echo ""
echo "   Watch load balancing across tasks (hostname changes each request):"
echo "   watch -n1 'curl -s $ALB_URL'"
