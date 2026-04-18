#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "=== System update ==="
dnf update -y

echo "=== Install CloudWatch agent ==="
dnf install -y amazon-cloudwatch-agent

echo "=== Start CloudWatch agent from SSM config ==="
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c ssm:/lab02/cloudwatch-agent/config \
  -s

systemctl enable amazon-cloudwatch-agent

echo "=== CPU load ==="
for i in {1..2}; do
  dd if=/dev/zero of=/dev/null bs=1M count=2000 &
done

sleep 60
pkill dd || true

echo "=== Done ==="