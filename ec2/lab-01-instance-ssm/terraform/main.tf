######################################
# VPCs
######################################
module "vpc" {
  source = "../../../_modules/vpc"
  vpc_cidr = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  vpc_name = "lab01-vpc"
}

######################################
# SG SSM
######################################
resource "aws_security_group" "ssm_sg" {
  name        = "ssm-sg"
  description = "SSM endpoints - no inbound from internet"
  vpc_id      = module.vpc.vpc_id

  # Required for SSM:
  # Allow EC2 instances in the VPC to reach the VPC endpoints over HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

######################################
# VPC endpoints
######################################
# These are Interface VPC Endpoints required for AWS Systems Manager (SSM) to work
# without going through the public internet. 
# 
# - ssm: allows the EC2 instance to communicate with the SSM service
# - ec2messages: supports the SSM agent messaging
# - ssmmessages: supports the SSM agent messaging
#
# private_dns_enabled = true ensures that DNS names like
# ssm.<region>.amazonaws.com resolve to the private IPs of the endpoints.
# The attached security group (ssm_sg) allows HTTPS (port 443) inbound
# from the VPC, which is necessary for SSM communication.
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [module.vpc.private_subnet_id]
  security_group_ids = [aws_security_group.ssm_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [module.vpc.private_subnet_id]
  security_group_ids = [aws_security_group.ssm_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [module.vpc.private_subnet_id]
  security_group_ids = [aws_security_group.ssm_sg.id]
  private_dns_enabled = true
}

######################################
# IAM Role
######################################
resource "aws_iam_role" "ec2_role" {
  name = "ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    tag-key = "tag-value"
  }
}

######################################
# Role Policy Attachments
######################################
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # Managed policy to allow SSM on the EC2 instance
}

######################################
# IAM Instance Profile
######################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

######################################
# EC2 Ubuntu AMI (dernière version Jammy 22.04)
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

  owners = ["099720109477"] # Canonical
}

######################################
# EC2 Instance
######################################
resource "aws_instance" "ssm_instance" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name
  vpc_security_group_ids = [aws_security_group.ssm_sg.id]
  subnet_id = module.vpc.private_subnet_id

  tags = {
    Name = "lab01-ssm-instance"
  }
}