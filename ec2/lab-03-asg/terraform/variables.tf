variable "region" {
  type    = string
  default = "eu-west-3"
}

variable "my_ip" {
  type        = string
  description = "Your public IP in CIDR notation (e.g. 82.123.45.67/32)"

  validation {
    condition     = can(cidrhost(var.my_ip, 0))
    error_message = "Must be a valid CIDR address (e.g. 82.123.45.67/32)."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the Launch Template"
  default     = "t3.micro"
}
