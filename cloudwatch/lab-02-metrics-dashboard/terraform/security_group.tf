# ==============================================================
# SECURITY GROUP
# ==============================================================

resource "aws_security_group" "lab02" {
  name        = "lab02-ec2-sg"
  description = "Security group for the lab-02 metrics dashboard"
  vpc_id      = data.aws_vpc.default.id

  # No inbound SSH — we use SSM Session Manager
  # If you want SSH, uncomment and adjust the CIDR:
  # ingress {
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["TON_IP/32"]
  # }

  egress {
    description = "Outbound internet access (to download the CloudWatch agent)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lab02-ec2-sg"
  }
}