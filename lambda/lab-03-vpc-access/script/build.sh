#!/usr/bin/env bash
# build.sh — Prepares the Lambda package (handler + dependencies)
#
# Usage: ./script/build.sh
# Run from the root of the lab (aws-labs/lambda/lab-03-vpc-access/)
# before running terraform apply.
#
# This script:
#   1. Installs pymysql into script/build/ (not included in AWS Python runtime)
#   2. Copies the Lambda handler
#   3. The ZIP file is created by Terraform via data.archive_file (source_dir = script/build/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

echo "-> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "-> Installing pymysql dependency..."
python3 -m pip install pymysql -t "$BUILD_DIR/" --quiet

echo "-> Copying Lambda handler..."
cp "$SCRIPT_DIR/handler.py" "$BUILD_DIR/"

echo "  Build completed: $BUILD_DIR"
echo "  Next step: cd terraform && terraform apply"