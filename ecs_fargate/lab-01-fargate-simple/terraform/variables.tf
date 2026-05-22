###############################################################################
# Variables
###############################################################################

variable "aws_region" {
  description = "AWS region where resources will be deployed"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project_name" {
  description = "Project name — used as a prefix for all resources"
  type        = string
  default     = "flask-lab-01"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "lab"
}

variable "app_port" {
  description = "Port exposed by the Flask application"
  type        = number
  default     = 5000
}

variable "task_cpu" {
  description = "CPU allocated to the task (256 = 0.25 vCPU)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.task_cpu)
    error_message = "Valid Fargate CPU values: 256, 512, 1024, 2048, 4096."
  }
}

variable "task_memory" {
  description = "Memory allocated to the task in MB"
  type        = number
  default     = 512

  validation {
    condition     = contains([512, 1024, 2048, 3072, 4096, 5120, 6144, 7168, 8192], var.task_memory)
    error_message = "Valid Fargate memory values for 256 CPU: 512 to 2048 MB."
  }
}

variable "desired_count" {
  description = "Number of ECS tasks to keep running continuously"
  type        = number
  default     = 1
}

###############################################################################
# Locals — calculated values and common tags
###############################################################################

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Lab         = "lab-01-fargate-simple"
  }
}