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
resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = false

  user_data = templatefile("${path.root}/../script/user_data.sh", {
    rds_endpoint = aws_db_instance.mysql.address
    secret_arn   = aws_db_instance.mysql.master_user_secret[0].secret_arn
    aws_region   = var.aws_region
  })

  user_data_replace_on_change = true

  tags = {
    Name = "${var.project_name}-ec2"
  }
}