######################################
# 1. VPC
######################################
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = { Name = "my-vpc" }
}

######################################
# 2. Internet Gateway
######################################
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = { Name = "internet-gateway" }
}

######################################
# 3. Subnets
######################################
# Public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = { Name = "public-subnet" }
}

# Private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"

  tags = { Name = "private-subnet" }
}

######################################
# 4. Route Tables
######################################
# Public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = { Name = "my-public-rt" }
}

# Private route table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  tags = { Name = "my-private-rt" }
}

######################################
# 5. Route Table Associations
######################################
# Public subnet ↔ Public route table
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Private subnet ↔ Private route table
resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}