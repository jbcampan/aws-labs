#!/bin/bash
apt update -y
apt install nginx -y
systemctl start nginx
systemctl enable nginx
echo "<h1>Hello from my EC2</h1>" > /var/www/html/index.html