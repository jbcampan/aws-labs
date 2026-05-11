variable "project_name" {
  type = string
  description = "Name of the project applied as prefix to resource names"

  default = "lab-02-event-driven"
}

variable "log_retention_days" {
  description = "Cloudwatch log retention in days"
  type = number
  
  default = 7

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "The value must be a valid CloudWatch retention period."
  }
}

variable "email_address" {
  type = string
  description = "Email address that will receive SNS messages"
  # export TF_VAR_email_address="your@email.com"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-3"
}