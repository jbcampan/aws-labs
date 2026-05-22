###############################################################################
# Security Group
# Controls inbound and outbound network traffic for ECS tasks
###############################################################################

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "Security group for ECS Fargate tasks"
  vpc_id      = module.vpc.vpc_id

  # Inbound: allow only the application port
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # OK for a lab environment — restrict in production
    description = "Access to the Flask application"
  }

  # Outbound: allow all traffic
  # Required for pulling images from ECR and sending logs to CloudWatch
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound: ECR pull, CloudWatch Logs"
  }

}