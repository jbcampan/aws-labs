# AWS region where all resources will be deployed
variable "aws_region" {
  type    = string
  default = "eu-west-3" # Paris
}

# Your public IP in CIDR notation — used to restrict SSH access
# Get it with: curl -4 ifconfig.me
# Then append /32 (e.g. 82.123.45.67/32)
variable "my_ip" {
  type = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0))
    error_message = "Must be a valid CIDR address (e.g. 82.123.45.67/32)."
  }
}