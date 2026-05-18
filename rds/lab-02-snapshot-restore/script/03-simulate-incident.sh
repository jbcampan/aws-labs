#!/usr/bin/env bash
# =============================================================================
# 03-simulate-incident.sh
# Simulate a production incident: data corruption / deletion.
# This script runs FROM the EC2 bastion host.
# =============================================================================
set -euo pipefail

RDS_HOST="${RDS_HOST:-}"
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-adminuser}"
DB_PASS="${DB_PASS:-}"

if [[ -z "$RDS_HOST" || -z "$DB_PASS" ]]; then
  echo "❌  Export RDS_HOST and DB_PASS before running this script."
  exit 1
fi

echo "════════════════════════════════════════════════════════"
echo "  💥  INCIDENT SIMULATION — $(date)"
echo "════════════════════════════════════════════════════════"
echo ""
echo "  Scenario: a developer runs a DELETE without WHERE"
echo "  on the orders table thinking they are cleaning the"
echo "  staging environment — but they are connected to prod."
echo ""
echo "  ⚠️  The following data will be DELETED:"
echo ""

# Display data that will be deleted
mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
  -e "SELECT id, customer, product, status FROM orders ORDER BY id;"

echo ""
read -r -p "  Continue the simulation? (type 'incident' to confirm) : " CONFIRM

if [[ "$CONFIRM" != "incident" ]]; then
  echo "  Simulation cancelled."
  exit 0
fi

echo ""
echo "  💣  Executing catastrophic DELETE …"
echo ""

mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<'SQL'
-- The incident: DELETE without WHERE (classic mistake)
DELETE FROM orders;

-- Post-incident verification
SELECT 'orders after incident' AS situation, COUNT(*) AS rows FROM orders;

-- The products table is intact but orders is empty
SELECT 'products untouched' AS situation, COUNT(*) AS rows FROM products;
SQL

echo ""
echo "  ✅  Incident simulated."
echo "      The 'orders' table is now empty."
echo ""
echo "  ── Incident timestamp ───────────────────────────────"
echo "  $(date -u '+%Y-%m-%dT%H:%M:%SZ')  (UTC)"
echo ""
echo "  Keep this timestamp for Point-in-Time Recovery."
echo ""
echo "  Next step: run 04-restore-from-snapshot.sh"