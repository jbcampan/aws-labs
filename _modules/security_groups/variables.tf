variable "vpc_id" {
  description = "ID of the VPC in which to create the Security Groups"
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR notation to restrict SSH access (e.g.: 82.123.45.67/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0))
    error_message = "Must be a valid CIDR address (e.g. 82.123.45.67/32)."
  }
}

variable "name_prefix" {
  description = "Prefix used to name all Security Groups (e.g.: 'lab03', 'prod')"
  type        = string
  default     = "main"
}
