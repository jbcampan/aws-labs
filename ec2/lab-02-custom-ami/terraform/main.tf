######################################
# VPC
######################################
module "vpc" {
    source = "../../../_modules/vpc"
    public_subnet_cidr = "10.0.1.0/24"
    private_subnet_cidr = "10.0.2.0/24"
    vpc_cidr = "10.0.0.0/16"
    vpc_name = "lab02-ec2"
}

######################################
# Security Group
######################################
module "security_group" {
  source      = "../../../_modules/security_groups"
  vpc_id      = module.vpc.vpc_id
  my_ip       = var.my_ip
  name_prefix = "lab02-ec2"
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
# Key Pair
######################################
resource "aws_key_pair" "lab02" {
  key_name   = "lab02-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

######################################
# EC2 Instance
######################################
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [
    module.security_group.sg_web_id,
    module.security_group.sg_ssh_id
    ]
  subnet_id = module.vpc.public_subnet_id
  key_name      = aws_key_pair.lab02.key_name
  associate_public_ip_address = true
  user_data = file("${path.module}/../script/custom-ami-nginx.sh")

  tags = {
    Name = "lab02-custom-ami"
  }
}