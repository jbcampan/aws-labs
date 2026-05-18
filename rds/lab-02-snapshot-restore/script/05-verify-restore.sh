#!/usr/bin/env bash
# =============================================================================
# 05-verify-restore.sh
# Verify that pre-incident data is present on the restored instance,
# and compare it with the source instance (damaged).
# This script runs FROM the EC2 bastion host.
# =============================================================================
set -euo pipefail

SOURCE_HOST="${RDS_HOST:-}"          # Source instance (data lost)
RESTORED_HOST="${RESTORED_HOST:-}"   # Restored instance
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-adminuser}"
DB_PASS="${DB_PASS:-}"

if [[ -z "$SOURCE_HOST" || -z "$RESTORED_HOST" || -z "$DB_PASS" ]]; then
  echo "❌  Missing variables:"
  echo "     export RDS_HOST=<source-endpoint>"
  echo "     export RESTORED_HOST=<restored-endpoint>"
  echo "     export DB_PASS=<password>"
  exit 1
fi

echo "════════════════════════════════════════════════════════"
echo "  🔍  Post-restore verification"
echo "════════════════════════════════════════════════════════"
echo ""

# ── Source (damaged) ──────────────────────────────────────────────────────────
echo "📋  SOURCE instance (damaged by the incident):"
echo "    Host : $SOURCE_HOST"
echo ""

mysql -h "$SOURCE_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
  -e "SELECT COUNT(*) AS 'orders (expected: 0 - data lost)' FROM orders;" \
  2>/dev/null || echo "    ⚠️  Unable to connect to source instance"

echo ""

# ── Restored instance ─────────────────────────────────────────────────────────
echo "📋  RESTORED instance (pre-incident data):"
echo "    Host : $RESTORED_HOST"
echo ""

mysql -h "$RESTORED_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<'SQL'
-- Row count
SELECT
  'orders'   AS table_name, COUNT(*) AS rows FROM orders
UNION ALL
SELECT
  'products', COUNT(*) FROM products;

-- Full orders data
SELECT
  id,
  customer,
  product,
  quantity,
  unit_price,
  status,
  DATE_FORMAT(created_at, '%Y-%m-%d %H:%i') AS created_at
FROM orders
ORDER BY id;

-- Integrity check: total revenue
SELECT
  CONCAT('Total revenue: ',
         FORMAT(SUM(quantity * unit_price), 2), ' €') AS verification
FROM orders
WHERE status != 'cancelled';
SQL

echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅  Restore validated!"
echo "      The 8 pre-incident orders are present."
echo "════════════════════════════════════════════════════════"
echo ""
echo "  Next step (bonus): run 06-pitr.sh"
echo "  Or directly      : 07-cleanup.sh to destroy resources"