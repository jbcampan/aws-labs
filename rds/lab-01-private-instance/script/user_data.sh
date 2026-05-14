#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

echo "=== Début user data ==="

# ── Système ────────────────────────────────────────────────────────────────────
apt-get update -y
apt-get install -y mysql-client awscli

# ── README ─────────────────────────────────────────────────────────────────────
cat > /home/ubuntu/README.md << 'EOF'
# Lab — RDS instance privée

## 1. Récupérer les credentials RDS depuis Secrets Manager

```bash
aws secretsmanager get-secret-value \
  --secret-id "${secret_arn}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text
```

Le résultat est un JSON avec les champs : username, password, host, port, dbname.

## 2. Se connecter à MySQL

```bash
mysql -h ${rds_endpoint} -u admin -p
```

Entrer le mot de passe récupéré à l'étape 1.

## 3. Exécuter les commandes SQL du lab

Une fois dans MySQL :

```sql
source /home/ubuntu/lab.sql
```

EOF

# ── Script de connexion ─────────────────────────────────────────────────────────
# Ce script récupère automatiquement le mot de passe et ouvre la session MySQL.
cat > /home/ubuntu/connect-rds.sh << 'EOF'
#!/bin/bash
set -e

SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "${secret_arn}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text)

PASSWORD=$(echo "$SECRET" | python3 -c "import sys, json; print(json.load(sys.stdin)['password'])")

echo "Connexion à ${rds_endpoint}..."
MYSQL_PWD="$PASSWORD" mysql -h "${rds_endpoint}" -u admin
EOF

chmod +x /home/ubuntu/connect-rds.sh

# ── Fichier SQL ─────────────────────────────────────────────────────────────────
cat > /home/ubuntu/lab.sql << 'EOF'
-- Création d'une table simple
CREATE TABLE IF NOT EXISTS users (
  id   INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100)
);

-- Insertion de données
INSERT INTO users (name) VALUES ('alice'), ('bob'), ('charlie');

-- Lecture
SELECT * FROM users;
EOF

# ── Permissions ─────────────────────────────────────────────────────────────────
chown ubuntu:ubuntu /home/ubuntu/README.md
chown ubuntu:ubuntu /home/ubuntu/connect-rds.sh
chown ubuntu:ubuntu /home/ubuntu/lab.sql

echo "=== Fin user data ==="