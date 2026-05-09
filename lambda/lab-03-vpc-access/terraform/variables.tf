variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "lab03"
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "labdb"
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS master password — do not commit"
  type        = string
  sensitive   = true
}
