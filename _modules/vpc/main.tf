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

# Private AZ-b (optional — RDS multi-AZ, Lambda multi-AZ)
resource "aws_subnet" "private_b" {
  count             = var.private_subnet_cidr_b != "" ? 1 : 0
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_b
  availability_zone = "${data.aws_region.current.name}b"

  tags = { Name = "${var.vpc_name}-private-subnet-b" }
}

######################################
# 4. NAT Gateway (optional)
#
# Required when resources in private subnets need to initiate
# outbound connections to the internet (Lambda → external APIs,
# image pulling, etc.).
#
# The NAT Gateway is placed in the PUBLIC subnet (AZ-a), which
# already has a route to the Internet Gateway (IGW). Private subnets
# route their 0.0.0.0/0 traffic through it.
#
# Why is enable_nat_gateway = false by default?
# A NAT Gateway costs ~0.045$/hour even without traffic. Labs that
# do not require outbound internet access from private subnets should
# avoid this cost.
######################################
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = { Name = "${var.vpc_name}-nat-eip" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id   # Must be in a PUBLIC subnet

  tags = { Name = "${var.vpc_name}-nat-gw" }

  depends_on = [aws_internet_gateway.main]
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

# The default route in the private route table is only added if a NAT Gateway exists.
# Without NAT: no routes → private subnets are fully isolated from the internet.
# With NAT   : 0.0.0.0/0 → NAT Gateway → internet access.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.main[0].id
    }
  }
  
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

#Private subnet B shares the same public route table.
resource "aws_route_table_association" "private_b" {
  count          = var.private_subnet_cidr_b != "" ? 1 : 0
  subnet_id      = aws_subnet.private_b[0].id
  route_table_id = aws_route_table.private.id
}

######################################
# 6. Data source région
######################################
data "aws_region" "current" {}