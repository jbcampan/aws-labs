###############################################################################
# ECS Cluster
# A Fargate cluster is just a logical namespace — no servers to manage.
# ECS automatically provisions compute capacity on demand.
###############################################################################

resource "aws_ecs_cluster" "main" {
  name = var.project_name

  # Enable Container Insights: enhanced CloudWatch metrics (CPU, memory per task)
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Capacity provider: specifies that we use Fargate
# (with optional Fargate Spot support)
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}


###############################################################################
# ECS Task Definition
# The container "blueprint": image, CPU, RAM, ports, env vars, logs
# Every change to this resource creates a NEW REVISION
# (e.g. flask-lab:1, flask-lab:2, flask-lab:3...)
###############################################################################

resource "aws_ecs_task_definition" "app" {
  family = var.project_name # Base name of the Task Definition

  # Fargate requires these two settings
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Required with Fargate — each task gets its own ENI

  # Resources allocated to the task (not the individual container)
  cpu    = var.task_cpu    # 256 = 0.25 vCPU
  memory = var.task_memory # 512 MB

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  # Container definitions inside the task (only one here)
  container_definitions = jsonencode([
    {
      name  = "app"
      image = "${aws_ecr_repository.app.repository_url}:latest"

      essential = true # If this container stops, the entire task stops

      portMappings = [
        {
          containerPort = var.app_port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "PORT"
          value = tostring(var.app_port)
        }
      ]

      # Log configuration → CloudWatch
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      # Enable ECS Exec (interactive shell inside the container)
      linuxParameters = {
        initProcessEnabled = true
      }

      # Health check: ECS verifies the app responds before marking it healthy
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])

  tags = local.common_tags
}

###############################################################################
# ECS Service
# Keeps N tasks running at all times.
# If a container crashes, ECS automatically starts a new one.
# The Service manages the task lifecycle (deployment, rollback).
###############################################################################

resource "aws_ecs_service" "app" {
  name    = "${var.project_name}-service"
  cluster = aws_ecs_cluster.main.id

  # Points to the Task Definition — ECS always uses the latest revision
  task_definition = aws_ecs_task_definition.app.arn

  desired_count = var.desired_count # Number of tasks to keep running

  launch_type = "FARGATE"

  # Enable ECS Exec for container debugging
  enable_execute_command = true

  # Network configuration: subnet and security group for each task
  network_configuration {
    subnets          = module.vpc.public_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true # Required in public subnets without a NAT Gateway
  }

  # Rolling deployment strategy: always keep at least 1 task running
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Wait until the service becomes stable before Terraform completes
  wait_for_steady_state = false

  # Prevent Terraform from redeploying if desired_count is changed manually
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}