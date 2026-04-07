######################################
# 1. SG WEB
######################################
resource "aws_security_group" "web" {
  name        = "${var.name_prefix}-sg-web"
  description = "HTTP/HTTPS open to the world"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-web" }
}

######################################
# 2. SG SSH
######################################
resource "aws_security_group" "ssh" {
  name        = "${var.name_prefix}-sg-ssh"
  description = "SSH restricted to a single IP"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH restricted to my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-ssh" }
}

######################################
# 3. SG DATABASE
######################################
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-sg-db"
  description = "MySQL access from web SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from web SG only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { Name = "${var.name_prefix}-sg-db" }
}
