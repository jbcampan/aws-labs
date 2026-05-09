#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Retrieving the path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# “Go to the Terraform directory
cd "$SCRIPT_DIR/../terraform"

# “Initialize and apply
terraform init
terraform apply -auto-approve