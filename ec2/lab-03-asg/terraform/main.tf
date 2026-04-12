######################################
# VPC — 2 subnets publics requis
######################################
module "vpc" {
  source = "../../../_modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  vpc_name             = "lab03-ec2-asg"
  public_subnet_cidr   = "10.0.1.0/24" # AZ-a
  public_subnet_cidr_b = "10.0.3.0/24" # AZ-b (new — required ALB)
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

# SG ALB — accepte HTTP depuis Internet
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

# Dedicated security group for EC2 instances
# Allows port 80 ONLY from the ALB security group (not from 0.0.0.0/0)
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

  # SSH access for stress test from your IP
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
# IAM Role
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

######################################
# Role Policy Attachments
######################################
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

######################################
# IAM Instance Profile
######################################
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "lab03-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

######################################
# EC2 Ubuntu AMI (dernière Jammy 22.04)
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
# Launch Template
######################################
resource "aws_launch_template" "lt" {
  name_prefix   = "lab03-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # Dedicated instance security group (HTTP from ALB only + SSH)
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
# Application Load Balancer
######################################
resource "aws_lb" "alb" {
  name               = "lab03-alb"
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb_sg.id]

  # Subnet list across 2 AZs (required by ALB)
  subnets = module.vpc.public_subnet_ids

  tags = { Name = "lab03-alb" }
}

######################################
# Target Group
######################################
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

######################################
# LB Listener
######################################
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
  name = "lab03-asg"

  min_size         = 1
  desired_capacity = 2
  max_size         = 4

  # Subnet list across 2 AZs (instances distributed between AZ-a and AZ-b)
  vpc_zone_identifier = module.vpc.public_subnet_ids

  target_group_arns = [aws_lb_target_group.tg.arn]

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
# Auto Scaling Policies (SimpleScaling)
######################################
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "lab03-scale-out"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "lab03-scale-in"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300 # more conservative for scale-in
}

######################################
# CloudWatch Alarms
######################################
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "lab03-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "lab03-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}
