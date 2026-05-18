terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────
# Data sources
# ─────────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ─────────────────────────────────────────────
# VPC & Networking
# ─────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.common_tags, { Name = "${var.project}-igw" })
}

# Public subnet (EC2 bastion)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, { Name = "${var.project}-public-subnet" })
}

# Private subnets (RDS subnet group requires at least 2 AZs)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = merge(var.common_tags, { Name = "${var.project}-private-subnet-a" })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = merge(var.common_tags, { Name = "${var.project}-private-subnet-b" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id  = aws_internet_gateway.main.id
  }

  tags = merge(var.common_tags, { Name = "${var.project}-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────────

resource "aws_security_group" "ec2_bastion" {
  name        = "${var.project}-ec2-bastion-sg"
  description = "Security group for EC2 bastion"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from your IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.project}-ec2-bastion-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Security group for MySQL RDS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from EC2 bastion"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, { Name = "${var.project}-rds-sg" })
}

# ─────────────────────────────────────────────
# RDS Subnet Group
# ─────────────────────────────────────────────

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = merge(var.common_tags, { Name = "${var.project}-subnet-group" })
}

# ─────────────────────────────────────────────
# RDS Parameter Group
# ─────────────────────────────────────────────

resource "aws_db_parameter_group" "mysql" {
  name   = "${var.project}-mysql-params"
  family = "mysql8.0"

  # Enable binlogs for PITR (Point-in-Time Recovery)
  parameter {
    name  = "binlog_format"
    value = "ROW"
  }

  tags = merge(var.common_tags, { Name = "${var.project}-mysql-params" })
}

# ─────────────────────────────────────────────
# Main RDS instance (snapshot source)
# ─────────────────────────────────────────────

resource "aws_db_instance" "source" {
  identifier = "${var.project}-source"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp2"
  storage_encrypted     = false # kept false for simplicity in lab

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name

  # Automated backups required for PITR
  backup_retention_period = 0  # Disable automated backups due to AWS free-tier restrictions; use a value > 0 to enable them
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  multi_az = false

  publicly_accessible = false

  skip_final_snapshot      = true
  delete_automated_backups = true
  deletion_protection      = false

  tags = merge(var.common_tags, {
    Name = "${var.project}-source"
    Role = "source"
    Note = "Source instance for snapshot/restore lab"
  })
}

# ─────────────────────────────────────────────
# EC2 Bastion (MySQL client)
# ─────────────────────────────────────────────

resource "aws_key_pair" "bastion" {
  key_name   = "${var.project}-bastion-key"
  public_key = file(var.public_key_path)

  tags = var.common_tags
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_bastion.id]
  key_name               = aws_key_pair.bastion.key_name

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y mysql
    echo "MySQL client installed" >> /var/log/lab-setup.log
  EOF

  tags = merge(var.common_tags, {
    Name = "${var.project}-bastion"
    Role = "bastion"
  })
}

# ─────────────────────────────────────────────
# IAM Role for SSM Session Manager (optional)
# ─────────────────────────────────────────────

resource "aws_iam_role" "ec2_ssm" {
  name = "${var.project}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm" {
  name = "${var.project}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm.name
}