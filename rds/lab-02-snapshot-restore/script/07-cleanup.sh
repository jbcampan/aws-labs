#!/usr/bin/env bash
# =============================================================================
# 07-cleanup.sh
# Delete resources created during the lab to avoid unnecessary costs.
# Order: restored RDS instances → snapshot → terraform destroy
# This script runs FROM your local machine.
# =============================================================================
set -euo pipefail

DB_INSTANCE_ID="${DB_INSTANCE_ID:-lab02-source}"
RESTORED_ID="${DB_INSTANCE_ID}-restored"
PITR_ID="${DB_INSTANCE_ID}-pitr"
SNAPSHOT_ID="${SNAPSHOT_ID:-}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
TERRAFORM_DIR="${TERRAFORM_DIR:-$(dirname "$0")/../terraform}"

echo "════════════════════════════════════════════════════════"
echo "  🧹  Cleaning up lab-02 resources"
echo "════════════════════════════════════════════════════════"
echo ""
echo "  Resources to delete:"
echo "  • Restored RDS instance : $RESTORED_ID"
echo "  • PITR RDS instance     : $PITR_ID (if created)"
echo "  • Manual snapshot       : ${SNAPSHOT_ID:-<to retrieve automatically>}"
echo "  • Terraform infrastructure (VPC, EC2, source RDS, SG…)"
echo ""

read -r -p "  Continue? (type 'cleanup' to confirm) : " CONFIRM

if [[ "$CONFIRM" != "cleanup" ]]; then
  echo "  Cancelled."
  exit 0
fi

echo ""

# ── Utility function ──────────────────────────────────────────────────────────
delete_rds_instance() {
  local INSTANCE_ID="$1"
  local EXISTS

  EXISTS=$(aws rds describe-db-instances \
    --db-instance-identifier "$INSTANCE_ID" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

  if [[ "$EXISTS" == "not-found" ]]; then
    echo "  ⏭️  $INSTANCE_ID not found, skipping."
    return
  fi

  echo "  🗑️  Deleting $INSTANCE_ID …"

  aws rds delete-db-instance \
    --db-instance-identifier   "$INSTANCE_ID" \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region "$AWS_REGION" \
    --output text > /dev/null

  echo "     Waiting for deletion …"

  while true; do
    STATUS=$(aws rds describe-db-instances \
      --db-instance-identifier "$INSTANCE_ID" \
      --region "$AWS_REGION" \
      --query 'DBInstances[0].DBInstanceStatus' \
      --output text 2>/dev/null || echo "deleted")

    if [[ "$STATUS" == "deleted" || "$STATUS" == "" ]]; then
      echo "     ✅  $INSTANCE_ID deleted."
      break
    fi

    printf "     Status: %s …\r" "$STATUS"
    sleep 15
  done
}

# ── 1. Delete restored instances ──────────────────────────────────────────────
echo "─── Step 1: Delete restored instances ──────────────────"

delete_rds_instance "$RESTORED_ID"
delete_rds_instance "$PITR_ID"

# ── 2. Delete manual snapshot ────────────────────────────────────────────────
echo ""
echo "─── Step 2: Delete manual snapshot ─────────────────────"

if [[ -z "$SNAPSHOT_ID" ]]; then
  echo "  SNAPSHOT_ID not defined, listing manual snapshots …"

  aws rds describe-db-snapshots \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --snapshot-type manual \
    --region "$AWS_REGION" \
    --query 'DBSnapshots[*].DBSnapshotIdentifier' \
    --output table

  read -r -p "  Enter snapshot identifier to delete (leave empty to skip) : " SNAPSHOT_ID
fi

if [[ -n "$SNAPSHOT_ID" ]]; then
  echo "  🗑️  Deleting snapshot $SNAPSHOT_ID …"

  aws rds delete-db-snapshot \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$AWS_REGION" \
    --output text > /dev/null

  echo "  ✅  Snapshot deleted."
else
  echo "  ⏭️  Snapshot skipped (delete manually if needed)."
fi

# ── 3. Terraform destroy ──────────────────────────────────────────────────────
echo ""
echo "─── Step 3: Terraform destroy (VPC, EC2, source RDS) ──"
echo ""

if [[ -d "$TERRAFORM_DIR" ]]; then
  cd "$TERRAFORM_DIR"
  terraform destroy -auto-approve

  echo ""
  echo "  ✅  Terraform infrastructure destroyed."
else
  echo "  ⚠️  Terraform directory not found: $TERRAFORM_DIR"
  echo "      Run manually: cd terraform && terraform destroy"
fi

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅  Cleanup complete. Cost = €0"
echo "════════════════════════════════════════════════════════"