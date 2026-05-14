variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "lab01-private-instance"
}


variable "db_name" {
  type        = string
  description = "MySQL database name"
  default     = "labdb"
}

variable "db_username" {
  type        = string
  description = "RDS master username"
  default     = "admin"
}