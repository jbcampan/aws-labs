terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "lab-01-orchestration-lambda"
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  prefix = "lab01"

  lambda_runtime = "python3.12"
  lambda_timeout = 30

  # Mapping: Lambda name → source directory
  lambdas = {
    validate-order    = "${path.module}/../lambdas/validate-order"
    check-inventory   = "${path.module}/../lambdas/check-inventory"
    process-payment   = "${path.module}/../lambdas/process-payment"
    send-confirmation = "${path.module}/../lambdas/send-confirmation"
    handle-failure    = "${path.module}/../lambdas/handle-failure"
  }
}