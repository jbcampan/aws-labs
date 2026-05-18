variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project" {
  description = "Prefix used to name all resources"
  type        = string
  default     = "lab02"
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "RDS admin username"
  type        = string
  default     = "adminuser"
}

variable "db_password" {
  description = "RDS admin password (use environment variable in production)"
  type        = string
  sensitive   = true
  # Provide via TF_VAR_db_password or non-committed terraform.tfvars
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR format (e.g. 1.2.3.4/32)"
  type        = string
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "lab02-snapshot-restore"
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}