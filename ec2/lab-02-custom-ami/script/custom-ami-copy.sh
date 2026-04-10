#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Getting the path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go in Terraform folder
cd "$SCRIPT_DIR/../terraform"

REGION_SOURCE=$(terraform output -raw region_source)
REGION_TARGET="us-east-1"
AMI_NAME="lab02-custom-ami-$(date +%Y%m%d-%H%M%S)"


######################################
# 1. Getting the instance ID
######################################
echo ">>> Getting the instance ID..."

INSTANCE_ID=$(terraform output -raw instance_id)

echo "Instance ID : $INSTANCE_ID"


######################################
# 2. Create the AMI
######################################
echo ">>> Creation of the AMI in $REGION_SOURCE..."

AMI_ID=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "$AMI_NAME" \
  --no-reboot \
  --region "$REGION_SOURCE" \
  --query "ImageId" \
  --output text)

echo "AMI created : $AMI_ID"


######################################
# 3. Wait for the AMI to be available
######################################
echo ">>> Waiting until the AMI is available..."

aws ec2 wait image-available \
  --image-ids "$AMI_ID" \
  --region "$REGION_SOURCE"

echo "AMI available."


######################################
# 4. Copy into the target region
######################################
echo ">>> Copying the AMI to $REGION_TARGET..."

AMI_COPY_ID=$(aws ec2 copy-image \
  --source-image-id "$AMI_ID" \
  --source-region "$REGION_SOURCE" \
  --region "$REGION_TARGET" \
  --name "$AMI_NAME-copy" \
  --query "ImageId" \
  --output text)

echo "AMI copied : $AMI_COPY_ID"


######################################
# 5. Wait for the copy to be available
######################################
echo ">>> Waiting for the copied AMI to become available in $REGION_TARGET..."

aws ec2 wait image-available \
  --image-ids "$AMI_COPY_ID" \
  --region "$REGION_TARGET"

echo "Copie available."

echo ""
echo "AMI source ($REGION_SOURCE) : $AMI_ID"
echo "AMI copy  ($REGION_TARGET) : $AMI_COPY_ID"