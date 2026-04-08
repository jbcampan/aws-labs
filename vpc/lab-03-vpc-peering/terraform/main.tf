######################################
# VPCs
######################################
module "vpc1" {
  source              = "../../../_modules/vpc"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
  vpc_name            = "lab03-vpc1"
}

module "vpc2" {
  source              = "../../../_modules/vpc"
  vpc_cidr            = "10.1.0.0/16"
  public_subnet_cidr  = "10.1.1.0/24"
  private_subnet_cidr = "10.1.2.0/24"
  vpc_name            = "lab03-vpc2"
}

######################################
# Security Groups (modules)
######################################
module "security_groups_vpc1" {
  source      = "../../../_modules/security_groups"
  vpc_id      = module.vpc1.vpc_id
  my_ip       = var.my_ip
  name_prefix = "lab03-vpc1"
}

module "security_groups_vpc2" {
  source      = "../../../_modules/security_groups"
  vpc_id      = module.vpc2.vpc_id
  my_ip       = var.my_ip
  name_prefix = "lab03-vpc2"
}

######################################
# Security Groups ICMP (peering)
# Outside of the module — specific to this lab
######################################
resource "aws_security_group" "allow_icmp_vpc1" {
  name        = "lab03-vpc1-allow-icmp"
  description = "Allow ICMP from VPC2 (10.1.0.0/16)"
  vpc_id      = module.vpc1.vpc_id

  ingress {
    description = "ICMP from VPC2"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  tags = {
    Name = "lab03-vpc1-allow-icmp"
  }
}

resource "aws_security_group" "allow_icmp_vpc2" {
  name        = "lab03-vpc2-allow-icmp"
  description = "Allow ICMP from VPC1 (10.0.0.0/16)"
  vpc_id      = module.vpc2.vpc_id

  ingress {
    description = "ICMP from VPC1"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "lab03-vpc2-allow-icmp"
  }
}

######################################
# VPC Peering
######################################
resource "aws_vpc_peering_connection" "vpc1_vpc2" {
  vpc_id      = module.vpc1.vpc_id
  peer_vpc_id = module.vpc2.vpc_id
  auto_accept = true

  tags = {
    Name = "lab03-vpc1-to-vpc2"
  }
}

######################################
# Routes peering
######################################
resource "aws_route" "vpc1_to_vpc2" {
  route_table_id            = module.vpc1.public_route_table_id
  destination_cidr_block    = "10.1.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc1_vpc2.id
}

resource "aws_route" "vpc2_to_vpc1" {
  route_table_id            = module.vpc2.public_route_table_id
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc1_vpc2.id
}

######################################
# AMI Ubuntu (dynamique)
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
resource "aws_key_pair" "lab03" {
  key_name   = "lab03-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

######################################
# EC2 instances
######################################
resource "aws_instance" "ec2_vpc1" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc1.public_subnet_id
  key_name      = aws_key_pair.lab03.key_name

  vpc_security_group_ids = [
    module.security_groups_vpc1.sg_web_id,
    module.security_groups_vpc1.sg_ssh_id,
    aws_security_group.allow_icmp_vpc1.id,
  ]

  tags = {
    Name = "lab03-instance-vpc1"
  }
}

resource "aws_instance" "ec2_vpc2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc2.public_subnet_id
  key_name      = aws_key_pair.lab03.key_name

  vpc_security_group_ids = [
    module.security_groups_vpc2.sg_web_id,
    module.security_groups_vpc2.sg_ssh_id,
    aws_security_group.allow_icmp_vpc2.id,
  ]

  tags = {
    Name = "lab03-instance-vpc2"
  }
}