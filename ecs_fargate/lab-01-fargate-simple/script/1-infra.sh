#!/usr/bin/env bash
# 1-infra.sh — Deploy AWS infrastructure with Terraform
#
# Usage: ./scripts/1-infra.sh

set -e

echo "=== Terraform init ==="
cd "$(dirname "$0")/../terraform"

terraform init

echo ""
echo "=== Terraform apply ==="
terraform apply

echo ""
echo "=== Outputs ==="
terraform output