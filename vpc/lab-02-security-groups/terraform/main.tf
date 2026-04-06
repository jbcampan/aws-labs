######################################
# DATA SOURCES
# Retrieves existing resources created in lab-01
# "data" creates nothing — it reads what already exists in AWS
######################################
data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["my-vpc"] # Tag defined in lab-01
  }
}

data "aws_subnet" "public" {
  filter {
    name   = "tag:Name"
    values = ["public-subnet"] # Tag defined in lab-01
  }
}

######################################
# 1. SG WEB
# HTTP/HTTPS traffic open to the world — this is intentional,
# this SG is designed for a public-facing web server
######################################
resource "aws_security_group" "sg_group_web" {
  name        = "sg_group_web"
  description = "Security group web"
  vpc_id      = data.aws_vpc.main.id

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the world
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Open to the world
  }

  # Outbound — all traffic allowed
  # SGs are stateful: responses to allowed inbound connections
  # are automatically permitted, without a dedicated egress rule.
  # This rule covers connections initiated by the instance itself
  # (system updates, external API calls, etc.)
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

######################################
# 2. SG SSH
# SSH access restricted to your IP only
# Never open port 22 to 0.0.0.0/0 in production:
# bots constantly scan this port
######################################
resource "aws_security_group" "sg_group_ssh" {
  name        = "sg_group_ssh"
  description = "Security group ssh"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description = "SSH restricted to my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip] # Defined in terraform.tfvars — never hardcoded
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

######################################
# 3. SG DATABASE
# MySQL access restricted to the web SG only
# Best practice: reference a SG rather than an IP —
# any instance carrying the web SG can reach the DB,
# regardless of its IP (useful if IP changes or when scaling)
######################################
resource "aws_security_group" "sg_group_db" {
  name        = "sg_group_db"
  description = "Security group db"
  vpc_id      = data.aws_vpc.main.id

  ingress {
    description     = "MySQL from web SG only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.sg_group_web.id] # SG → SG reference, not an IP
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

######################################
# 4. AMI
# Dynamically fetches the latest Ubuntu AMI
# Avoids hardcoding an AMI ID that becomes outdated with updates
# and differs across AWS regions
######################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical — filters out unofficial third-party AMIs
}

######################################
# 5. KEY PAIR
# Uploads the local public key to AWS
# The private key (~/.ssh/id_rsa) stays on your machine and never leaves
# AWS injects the public key into the instance at boot
######################################
resource "aws_key_pair" "deployer" {
  key_name   = "lab02-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

######################################
# 6. EC2 INSTANCE
# Test instance in the public subnet
# Carries the web and ssh SGs — not the db SG (no MySQL here)
######################################
resource "aws_instance" "my_ec2_lab02_sg" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_subnet.public.id
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [
    aws_security_group.sg_group_web.id,
    aws_security_group.sg_group_ssh.id
    # sg_group_db is not attached here — it will be attached to an RDS instance in a future lab
  ]

  tags = {
    Name = "lab02-instance"
  }
}