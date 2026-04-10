variable "region" {
    type = string

    default = "eu-west-3"
}

variable "my_ip" {
  type = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0))
    error_message = "Must be a valid CIDR address (e.g. 82.123.45.67/32)."
  }
}