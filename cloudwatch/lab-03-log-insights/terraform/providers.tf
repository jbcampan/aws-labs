######################################
# Terraform & Providers
######################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

######################################
# AWS Provider
######################################
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "lab-03-log-insights"
      ManagedBy   = "terraform"
    }
  }
}