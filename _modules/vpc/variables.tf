variable "vpc_cidr" {
  description = "VPC CIDR block (e.g.: 10.0.0.0/16)"
  type        = string
}

variable "vpc_name" {
  description = "Prefix used to name all module resources"
  type        = string
  default     = "main"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block (e.g.: 10.0.1.0/24)"
  type        = string
}

variable "private_subnet_cidr" {
  description = "Private subnet CIDR block (e.g.: 10.0.2.0/24)"
  type        = string
}
