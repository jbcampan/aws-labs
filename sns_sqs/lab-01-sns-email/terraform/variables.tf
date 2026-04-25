variable "aws_region" {
  description = "Target AWS region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "email_address" {
  description = "Email address that will receive SNS messages"
  type        = string
  # export TF_VAR_email_address="your@email.com"
}