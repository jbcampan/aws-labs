######################################
# 1. VPC
######################################
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

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
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true

  tags = { Name = "${var.vpc_name}-public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr

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

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
