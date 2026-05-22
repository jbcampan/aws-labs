#!/usr/bin/env bash
# 2-push.sh — Build the Docker image and push it to ECR
#
# Prerequisite: run 1-infra.sh at least once
# Usage       : ./scripts/2-push.sh

set -e

# Fetch values from Terraform outputs
cd "$(dirname "$0")/../terraform"

ECR_URL=$(terraform output -raw ecr_repository_url)
ECR_REGISTRY=$(echo "$ECR_URL" | cut -d'/' -f1)  # e.g., 123456789.dkr.ecr.eu-west-3.amazonaws.com
AWS_REGION=$(terraform output -raw aws_region)

echo "=== Docker login → ECR ==="
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"

echo ""
echo "=== Build the image ==="
cd ../app
docker build -t flask-lab .

echo ""
echo "=== Tag ==="
docker tag flask-lab:latest "$ECR_URL:latest"

echo ""
echo "=== Push to ECR ==="
docker push "$ECR_URL:latest"

echo ""
echo "Image available at: $ECR_URL:latest"