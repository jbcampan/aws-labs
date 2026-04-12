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
  default     = "t2.micro"
}

variable "cpu_target_value" {
  type        = number
  description = <<-EOT
    CPU utilization target (%) for TargetTrackingScaling.
    AWS will scale out when average CPU exceeds this value
    and scale in when it drops below it.
    Recommended: 50 for lab (leaves headroom before max).
  EOT
  default     = 50

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value < 100
    error_message = "cpu_target_value must be between 1 and 99."
  }
}
