#!/bin/bash
set -e

# Mise à jour système
apt update -y

# Installation Nginx + stress tool
apt install -y nginx stress

# Démarrage et activation de Nginx
systemctl start nginx
systemctl enable nginx

# Page web simple pour tester ALB + load balancing
echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html

# (optionnel) log pour debug user_data
echo "User data executed at $(date)" >> /var/log/user-data.log