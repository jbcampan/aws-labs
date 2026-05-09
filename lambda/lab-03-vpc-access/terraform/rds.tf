# ─── SECURITY GROUPS ──────────────────────────────────────────────────────────
#
# Principle: the RDS security group references the Lambda security group ID
# as its source, instead of a CIDR range. Benefit: if the Lambda SG is
# modified or deleted, access is automatically revoked.
# This is more secure than a CIDR-based rule, which could unintentionally
# allow any resource in the subnet.

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Lambda - unrestricted egress, no ingress (Lambda does not receive inbound connections)"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "All outbound traffic (RDS in-VPC + internet via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-lambda-sg" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS MySQL - inbound access on port 3306 from Lambda SG only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "MySQL access from Lambda only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# ─── RDS MYSQL ────────────────────────────────────────────────────────────────
#
# The DB subnet group defines in which subnets RDS will be deployed.
# AWS requires at least 2 subnets in different AZs, even for single-AZ setups.
# This is why private_subnet_cidr_b was enabled in the VPC module.
#
# module.vpc.private_subnet_ids returns a compact list:
#   ["subnet-aaa (AZ-a)", "subnet-bbb (AZ-b)"]

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_db_instance" "mysql" {
  identifier        = "${var.project_name}-mysql"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az            = false  # Single-AZ is sufficient for a lab
  publicly_accessible = false  # Never expose RDS to the internet
  skip_final_snapshot = true   # Allows terraform destroy without blocking
  deletion_protection = false

  tags = { Name = "${var.project_name}-mysql" }
}