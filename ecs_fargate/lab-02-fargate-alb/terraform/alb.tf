# ─── Application Load Balancer ──────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  # In production: set enable_deletion_protection = true
  enable_deletion_protection = false

  tags = { Name = "${var.project_name}-alb" }
}

# ─── Target Group ────────────────────────────────────────────────────────────
# ECS automatically registers and deregisters tasks here

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip" # Required for Fargate (no instance IDs)

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # Reduced delay for lab environments — Fargate tasks stop quickly
  deregistration_delay = 30

  tags = { Name = "${var.project_name}-tg" }
}

# ─── HTTP Listener :80 ───────────────────────────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}