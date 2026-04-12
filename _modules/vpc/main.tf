######################################
# 1. VPC
######################################
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Added later for the SSM (ec2/lab01-instance_ssm):
  enable_dns_support   = true   # Enables DNS resolution within the VPC (required to resolve AWS service endpoints) 
  enable_dns_hostnames = true   # Allows resources in the VPC to have internal DNS hostnames. Required for private_dns_enabled on VPC endpoints to work properly

  tags = { Name = var.vpc_name }
}

######################################
# 2. Internet Gateway
######################################
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.vpc_name}-igw" }
}

######################################
# 3. Subnets
######################################

# Public AZ-a (already existing)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${data.aws_region.current.name}a"
  map_public_ip_on_launch = true

  tags = { Name = "${var.vpc_name}-public-subnet-a" }
}

# Public AZ-b (new — required for multi-AZ ALB + ASG)
resource "aws_subnet" "public_b" {
  count  = var.public_subnet_cidr_b != "" ? 1 : 0
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_b
  availability_zone       = "${data.aws_region.current.name}b"
  map_public_ip_on_launch = true

  tags = { Name = "${var.vpc_name}-public-subnet-b" }
}

# Private AZ-a
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  availability_zone = "${data.aws_region.current.name}a"

  tags = { Name = "${var.vpc_name}-private-subnet" }
}

######################################
# 4. Route Tables
######################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.vpc_name}-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.vpc_name}-private-rt" }
}

######################################
# 5. Route Table Associations
######################################
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Public subnet B shares the same public route table.
resource "aws_route_table_association" "public_b" {
  count          = var.public_subnet_cidr_b != "" ? 1 : 0
  subnet_id      = aws_subnet.public_b[0].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

######################################
# 6. Data source région
######################################
data "aws_region" "current" {}