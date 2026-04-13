variable "region" {
  type    = string
  default = "us-east-1"

  validation {
    condition     = var.region == "us-east-1"
    error_message = "Les métriques AWS Billing ne sont disponibles que dans us-east-1."
  }
}

variable "alert_email" {
  description = "Email address to receive billing alerts"
  type        = string
}