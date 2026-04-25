variable "aws_region" {
  description = "Target AWS region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project_name" {
  description = "Prefix used for all resource names"
  type        = string
  default     = "lab02"
}

variable "failure_rate" {
  description = "Simulated Lambda failure rate (0.0 to 1.0)"
  type        = string
  default     = "0.4" # 40% of messages will intentionally fail
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "aws-labs"
    Lab         = "02-sqs-lambda"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}