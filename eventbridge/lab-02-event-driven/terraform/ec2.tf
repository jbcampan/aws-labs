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
resource "aws_instance" "my_ec2_lab02_eventbridge" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  associate_public_ip_address = false
}