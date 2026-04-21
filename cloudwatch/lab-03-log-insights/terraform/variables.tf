######################################
# AWS Region
######################################
variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

######################################
# Environment
######################################
variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "lab"
}

######################################
# Lambda Function Name
######################################
variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "lab03-log-insights"
}