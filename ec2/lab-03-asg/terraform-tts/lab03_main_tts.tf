######################################
# VPC — 2 subnets publics requis
######################################
module "vpc" {
  source = "../../../_modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  vpc_name             = "lab03-ec2-asg"
  public_subnet_cidr   = "10.0.1.0/24"
  public_subnet_cidr_b = "10.0.3.0/24"
  private_subnet_cidr  = "10.0.2.0/24"
}

######################################
# Security Groups
######################################
module "security_group" {
  source      = "../../../_modules/security_groups"
  vpc_id      = module.vpc.vpc_id
  my_ip       = var.my_ip
  name_prefix = "lab03-ec2-asg"
}

resource "aws_security_group" "alb_sg" {
  name        = "lab03-alb-sg"
  description = "HTTP open to the world for the ALB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lab03-alb-sg" }
}

resource "aws_security_group" "instance_sg" {
  name        = "lab03-instance-sg"
  description = "Allow HTTP only from ALB, SSH from my IP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lab03-instance-sg" }
}

######################################
# IAM
######################################
resource "aws_iam_role" "ec2_role" {
  name = "lab03-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = { Name = "lab03-ec2-role" }
}

resource "aws_iam_role_policy_attachment" "ec2_readonly" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "lab03-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

######################################
# AMI Ubuntu 22.04
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

  owners = ["099720109477"]
}

######################################
# Launch Template
######################################
resource "aws_launch_template" "lt" {
  name_prefix   = "lab03-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = filebase64("${path.module}/../script/asg-nginx.sh")

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "lab03-asg-instance" }
  }
}

######################################
# ALB
######################################
resource "aws_lb" "alb" {
  name               = "lab03-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnet_ids

  tags = { Name = "lab03-alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "lab03-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 15
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

######################################
# Auto Scaling Group
######################################
resource "aws_autoscaling_group" "asg" {
  name             = "lab03-asg"
  min_size         = 1
  desired_capacity = 2
  max_size         = 4

  vpc_zone_identifier = module.vpc.public_subnet_ids
  target_group_arns   = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 120

  force_delete = true

  tag {
    key                 = "Name"
    value               = "lab03-asg-instance"
    propagate_at_launch = true
  }
}

######################################
#  — TargetTrackingScaling —
#
# Replaces the 4 resources from step 2:
#   - aws_autoscaling_policy.scale_out
#   - aws_autoscaling_policy.scale_in
#   - aws_cloudwatch_metric_alarm.cpu_high
#   - aws_cloudwatch_metric_alarm.cpu_low
#
# AWS automatically creates and manages two
# CloudWatch alarms behind the scenes
# (scale-out and scale-in).
# Instance delta is dynamically calculated
# to converge toward target_value, not a fixed +1.
######################################
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "lab03-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  # TargetTracking: we define a goal, not an action
  policy_type = "TargetTrackingScaling"

  target_tracking_configuration {
    # Predefined metric — no need to define namespace/dimensions
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    # Goal: keep average CPU at 50%
    # AWS scales out if CPU > 50%, scales in if CPU < 50%
    # (with an internal tolerance band to prevent flapping)
    target_value = var.cpu_target_value

    # Disable automatic scale-in if you want to manage it manually.
    # false = AWS can also reduce the number of instances (normal behavior).
    disable_scale_in = false
  }
}
