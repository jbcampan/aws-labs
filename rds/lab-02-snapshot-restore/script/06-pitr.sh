#!/usr/bin/env bash
# =============================================================================
# 06-pitr.sh  (BONUS)
# Point-in-Time Recovery: restore to a specific timestamp.
# More precise than a snapshot — RDS replays transaction logs.
# Requires backup_retention_period > 0 on the source instance.
# This script runs FROM your local machine.
# =============================================================================
set -euo pipefail

DB_INSTANCE_ID="${DB_INSTANCE_ID:-lab02-source}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
PITR_ID="${DB_INSTANCE_ID}-pitr"

# ── Retrieve available restore window ────────────────────────────────────────
echo "════════════════════════════════════════════════════════"
echo "  ⏱️   Point-in-Time Recovery (PITR)"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🔍  Checking available PITR window …"
echo ""

aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].{
    BackupRetentionPeriod: BackupRetentionPeriod,
    LatestRestorableTime: LatestRestorableTime,
    EarliestRestorableTime: BackupRetentionPeriod
  }' \
  --output table

LATEST_RESTORABLE=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].LatestRestorableTime' \
  --output text)

echo ""
echo "  Latest restorable point : $LATEST_RESTORABLE"
echo ""

# ── Enter target timestamp ───────────────────────────────────────────────────
echo "  Enter the restore timestamp (BEFORE the incident)."
echo "  ISO 8601 UTC format : 2024-01-15T14:30:00Z"
echo "  Tip: use the timestamp noted in 03-simulate-incident.sh"
echo "       minus a few minutes to ensure it is before the incident."
echo ""

read -r -p "  Target timestamp (UTC) : " RESTORE_TIME

if [[ -z "$RESTORE_TIME" ]]; then
  echo "❌  Empty timestamp. Cancelling."
  exit 1
fi

# ── Retrieve network configuration ───────────────────────────────────────────
SUBNET_GROUP=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' \
  --output text)

VPC_SG=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' \
  --output text)

echo ""
echo "════════════════════════════════════════════════════════"
echo "  PITR Restore"
echo "  Source    : $DB_INSTANCE_ID"
echo "  Target    : $PITR_ID"
echo "  Timestamp : $RESTORE_TIME"
echo "════════════════════════════════════════════════════════"
echo ""

START=$(date +%s)

# ── Start PITR ───────────────────────────────────────────────────────────────
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier "$DB_INSTANCE_ID" \
  --target-db-instance-identifier "$PITR_ID" \
  --restore-time                   "$RESTORE_TIME" \
  --db-instance-class              "db.t3.micro" \
  --db-subnet-group-name           "$SUBNET_GROUP" \
  --vpc-security-group-ids         "$VPC_SG" \
  --no-multi-az \
  --no-publicly-accessible \
  --tags \
    Key=Project,Value=lab02-snapshot-restore \
    Key=Environment,Value=lab \
    Key=RestoreType,Value=PITR \
    Key=RestoreTimestamp,Value="$RESTORE_TIME" \
  --region "$AWS_REGION" \
  --output table

echo ""
echo "⏳  Waiting for availability …"
echo ""

# ── Polling ───────────────────────────────────────────────────────────────────
while true; do
  STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$PITR_ID" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "creating")

  ELAPSED=$(( $(date +%s) - START ))
  printf "\r  Status: %-15s | Elapsed: %ds   " "$STATUS" "$ELAPSED"

  if [[ "$STATUS" == "available" ]]; then
    echo ""
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo ""
    echo "❌  PITR failed."
    exit 1
  fi

  sleep 20
done

PITR_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$PITR_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

ELAPSED=$(( $(date +%s) - START ))

echo ""
echo "✅  PITR completed in $((ELAPSED/60))m$((ELAPSED%60))s"
echo ""
echo "  PITR endpoint : $PITR_ENDPOINT"
echo ""
echo "  Difference between PITR and Snapshot:"
echo "  • Snapshot  = fixed state at snapshot creation time"
echo "  • PITR      = exact state at $RESTORE_TIME (transaction log replay)"
echo "    → If you inserted data AFTER the snapshot and BEFORE the incident,"
echo "      PITR restores it, unlike the snapshot."
echo ""
echo "  export PITR_HOST=$PITR_ENDPOINT"
echo ""
echo "  Connect from the bastion host to verify:"
echo "  mysql -h \$PITR_HOST -u adminuser -p appdb"
echo ""
echo "  Next step: 07-cleanup.sh"