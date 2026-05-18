#!/usr/bin/env bash
# =============================================================================
# 01-seed-data.sh
# Populate the source RDS database with realistic test data.
# This script runs FROM the EC2 bastion host.
# =============================================================================
set -euo pipefail
# set -euo pipefail :
# -e => stop on error
# -u => error if variable is undefined
# pipefail => propagate errors through pipes

# ── Variables — adapt or pass through environment ────────────────────────────
RDS_HOST="${RDS_HOST:-}"       # export RDS_HOST=xxxx.rds.amazonaws.com
DB_NAME="${DB_NAME:-appdb}"
DB_USER="${DB_USER:-adminuser}"
DB_PASS="${DB_PASS:-}"         # export DB_PASS=...

# ── Validation ───────────────────────────────────────────────────────────────
if [[ -z "$RDS_HOST" || -z "$DB_PASS" ]]; then
  echo "❌  Missing variables. Export:"
  echo "     export RDS_HOST=\$(terraform output -raw rds_source_endpoint | cut -d: -f1)"
  echo "     export DB_PASS='ChangeMe123!'"
  exit 1
fi

echo "🔌 Connecting to $RDS_HOST/$DB_NAME as $DB_USER …"

mysql -h "$RDS_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<'SQL'
-- ────────────────────────────────────────────
-- Schema
-- ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS orders (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  customer    VARCHAR(100)   NOT NULL,
  product     VARCHAR(100)   NOT NULL,
  quantity    INT            NOT NULL DEFAULT 1,
  unit_price  DECIMAL(10,2)  NOT NULL,
  status      ENUM('pending','shipped','delivered','cancelled') NOT NULL DEFAULT 'pending',
  created_at  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS products (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  sku         VARCHAR(50)    NOT NULL UNIQUE,
  name        VARCHAR(200)   NOT NULL,
  stock       INT            NOT NULL DEFAULT 0,
  price       DECIMAL(10,2)  NOT NULL,
  created_at  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────
-- Test data
-- ────────────────────────────────────────────
INSERT INTO products (sku, name, stock, price) VALUES
  ('SKU-001', 'Mechanical TKL Keyboard',      42,  89.99),
  ('SKU-002', 'Ergonomic Wireless Mouse',     15,  49.99),
  ('SKU-003', '27" 4K IPS Monitor',            8, 449.00),
  ('SKU-004', '7-Port USB-C Hub',             30,  35.00),
  ('SKU-005', 'ANC Headphones',               20, 199.99)
ON DUPLICATE KEY UPDATE stock = VALUES(stock);

INSERT INTO orders (customer, product, quantity, unit_price, status) VALUES
  ('Alice Martin',    'Mechanical TKL Keyboard',   1,  89.99, 'delivered'),
  ('Bob Dupont',      '27" 4K IPS Monitor',        2, 449.00, 'shipped'),
  ('Claire Morel',    'Ergonomic Wireless Mouse',  1,  49.99, 'delivered'),
  ('David Leroy',     '7-Port USB-C Hub',          3,  35.00, 'pending'),
  ('Emma Bernard',    'ANC Headphones',            1, 199.99, 'shipped'),
  ('Fabrice Simon',   'Mechanical TKL Keyboard',   2,  89.99, 'pending'),
  ('Géraldine Petit', 'Ergonomic Wireless Mouse',  1,  49.99, 'delivered'),
  ('Henri Robert',    '27" 4K IPS Monitor',        1, 449.00, 'cancelled');

-- ────────────────────────────────────────────
-- Verification
-- ────────────────────────────────────────────
SELECT 'products' AS table_name, COUNT(*) AS row_count FROM products
UNION ALL
SELECT 'orders',                  COUNT(*)               FROM orders;
SQL

echo ""
echo "✅  Data inserted successfully."
echo "    Next step: run 02-create-snapshot.sh"