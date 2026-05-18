#!/usr/bin/env bash
# =============================================================================
# 02-create-snapshot.sh
# Create a manual RDS snapshot and wait for completion.
# This script runs FROM your local machine (AWS CLI configured).
# =============================================================================
set -euo pipefail

# ── Variables ─────────────────────────────────────────────────────────────────
DB_INSTANCE_ID="${DB_INSTANCE_ID:-lab02-source}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
DATE_TAG=$(date +%Y%m%d-%H%M)
SNAPSHOT_ID="${DB_INSTANCE_ID}-manual-${DATE_TAG}"

echo "════════════════════════════════════════════════════════"
echo "  📸  Creating manual RDS snapshot"
echo "  Instance  : $DB_INSTANCE_ID"
echo "  Snapshot  : $SNAPSHOT_ID"
echo "  Region    : $AWS_REGION"
echo "════════════════════════════════════════════════════════"
echo ""

# ── Create snapshot ───────────────────────────────────────────────────────────
echo "⏳  Triggering snapshot …"

aws rds create-db-snapshot \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --db-snapshot-identifier  "$SNAPSHOT_ID" \
  --tags \
    Key=Project,Value=lab02-snapshot-restore \
    Key=Environment,Value=lab \
    Key=CreatedAt,Value="$DATE_TAG" \
    Key=Note,Value="Snapshot-before-simulated-incident" \
  --region "$AWS_REGION" \
  --output table

echo ""
echo "⏳  Waiting for snapshot completion (may take 5-15 min) …"
echo "    Press Ctrl+C to exit — the snapshot will continue in the background."
echo ""

# ── Poll until available ──────────────────────────────────────────────────────
START=$(date +%s)

while true; do
  STATUS=$(aws rds describe-db-snapshots \
    --db-snapshot-identifier "$SNAPSHOT_ID" \
    --region "$AWS_REGION" \
    --query 'DBSnapshots[0].Status' \
    --output text 2>/dev/null || echo "pending")

  ELAPSED=$(( $(date +%s) - START ))
  printf "\r  Status: %-12s | Elapsed: %ds   " "$STATUS" "$ELAPSED"

  if [[ "$STATUS" == "available" ]]; then
    echo ""
    echo ""
    echo "✅  Snapshot is ready!"
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo ""
    echo "❌  Snapshot failed. Check the AWS console."
    exit 1
  fi

  sleep 15
done

# ── Final information ─────────────────────────────────────────────────────────
echo ""
echo "─── Snapshot details ─────────────────────────────────"
aws rds describe-db-snapshots \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --region "$AWS_REGION" \
  --query 'DBSnapshots[0].{
    Identifier: DBSnapshotIdentifier,
    Status: Status,
    CreatedAt: SnapshotCreateTime,
    AllocatedStorage: AllocatedStorage,
    EncryptedYN: Encrypted
  }' \
  --output table

echo ""
echo "  ⚠️  SAVE this identifier for the next step:"
echo "  SNAPSHOT_ID=$SNAPSHOT_ID"
echo ""
echo "  export SNAPSHOT_ID=$SNAPSHOT_ID"
echo ""
echo "  Next step: run 03-simulate-incident.sh"