variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "alert_email" {
  description = "Email address to receive billing alerts"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the SSH key pair (leave empty if not needed)"
  type        = string
  default     = ""
}
