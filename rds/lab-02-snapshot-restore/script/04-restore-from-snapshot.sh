#!/usr/bin/env bash
# =============================================================================
# 04-restore-from-snapshot.sh
# Restore a new RDS instance from the manual snapshot.
# ⚠️  Creates a NEW instance — not an in-place restore.
# This script runs FROM your local machine.
# =============================================================================
set -euo pipefail

# ── Variables ─────────────────────────────────────────────────────────────────
SNAPSHOT_ID="${SNAPSHOT_ID:-}"            # export SNAPSHOT_ID=lab02-source-manual-YYYYMMDD-HHMM
DB_INSTANCE_ID="${DB_INSTANCE_ID:-lab02-source}"
AWS_REGION="${AWS_REGION:-eu-west-3}"
RESTORED_ID="${DB_INSTANCE_ID}-restored"

if [[ -z "$SNAPSHOT_ID" ]]; then
  echo "❌  SNAPSHOT_ID is not defined."
  echo "    List available snapshots:"
  echo ""

  aws rds describe-db-snapshots \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --query 'DBSnapshots[*].{ID:DBSnapshotIdentifier,Status:Status,Created:SnapshotCreateTime}' \
    --output table \
    --region "$AWS_REGION"

  echo ""
  echo "    Then run: export SNAPSHOT_ID=<identifier>"
  exit 1
fi

# Retrieve subnet group and security group from source instance
echo "🔍  Retrieving network configuration from source instance …"

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

PARAM_GROUP=$(aws rds describe-db-instances \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].DBParameterGroups[0].DBParameterGroupName' \
  --output text)

echo ""
echo "════════════════════════════════════════════════════════"
echo "  🔄  Restore from snapshot"
echo "  Snapshot         : $SNAPSHOT_ID"
echo "  New instance     : $RESTORED_ID"
echo "  Subnet Group     : $SUBNET_GROUP"
echo "  Security Group   : $VPC_SG"
echo "════════════════════════════════════════════════════════"
echo ""

START=$(date +%s)

echo "⏳  Starting restore …"
echo "    (The new instance will have a NEW endpoint — save it for later)"
echo ""

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier  "$RESTORED_ID" \
  --db-snapshot-identifier  "$SNAPSHOT_ID" \
  --db-instance-class        "db.t3.micro" \
  --db-subnet-group-name     "$SUBNET_GROUP" \
  --vpc-security-group-ids   "$VPC_SG" \
  --db-parameter-group-name  "$PARAM_GROUP" \
  --no-multi-az \
  --no-publicly-accessible \
  --no-auto-minor-version-upgrade \
  --tags \
    Key=Project,Value=lab02-snapshot-restore \
    Key=Environment,Value=lab \
    Key=RestoredFrom,Value="$SNAPSHOT_ID" \
    Key=RestoredAt,Value="$(date +%Y%m%d-%H%M)" \
  --region "$AWS_REGION" \
  --output table

echo ""
echo "⏳  Waiting for availability (10-30 min depending on size) …"
echo "    This is where the real RTO is measured."
echo ""

# ── Polling ───────────────────────────────────────────────────────────────────
while true; do
  STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier "$RESTORED_ID" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "creating")

  ELAPSED=$(( $(date +%s) - START ))
  MINUTES=$(( ELAPSED / 60 ))
  SECONDS=$(( ELAPSED % 60 ))
  printf "\r  Status: %-15s | Elapsed time: %dm%ds   " "$STATUS" "$MINUTES" "$SECONDS"

  if [[ "$STATUS" == "available" ]]; then
    echo ""
    echo ""
    echo "✅  Instance restored in ${MINUTES}m${SECONDS}s  ← this is your observed RTO"
    break
  elif [[ "$STATUS" == "failed" ]]; then
    echo ""
    echo "❌  Restore failed."
    exit 1
  fi

  sleep 20
done

# ── New instance endpoint ─────────────────────────────────────────────────────
RESTORED_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$RESTORED_ID" \
  --region "$AWS_REGION" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

echo ""
echo "─── Connection information ─────────────────────────────"
echo "  New instance   : $RESTORED_ID"
echo "  New endpoint   : $RESTORED_ENDPOINT"
echo ""
echo "  ⚠️  In production, you would now need to update"
echo "      the application's connection strings to point"
echo "      to this new endpoint. That's the real challenge"
echo "      of a restore operation."
echo ""
echo "  export RESTORED_HOST=$RESTORED_ENDPOINT"
echo ""
echo "  Next step: run 05-verify-restore.sh"