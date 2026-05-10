###############################################################################
# lab-01-scheduled-rule — Terraform Variables
###############################################################################

variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project_name" {
  description = "Project name — used as a prefix for all resources"
  type        = string
  default     = "lab-01-scheduled-rule"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table to query (created in lab-lambda-02)"
  type        = string
  default     = "lab-01-scheduled-rule-items"
}

variable "schedule_expression" {
  description = <<-EOT
    EventBridge schedule expression.
    Two supported syntaxes:

    Rate syntax (simpler):
      rate(5 minutes)   → every 5 minutes
      rate(1 hour)      → every hour
      rate(1 day)       → every 24 hours

    Cron syntax (more precise):
      cron(0 8 * * ? *)          → every day at 08:00 UTC
      cron(0 8 ? * MON-FRI *)    → Monday to Friday at 08:00 UTC
      cron(0/5 * * * ? *)        → every 5 minutes

    AWS NOTE: the Day-of-week field uses SUN/MON/TUE/WED/THU/FRI/SAT
    and cannot be combined with Day-of-month (use ? for one of the two fields).
  EOT
  type        = string
  default     = "rate(5 minutes)" # Convenient for observation during the lab
}

variable "rule_enabled" {
  description = <<-EOT
    Enables or disables the EventBridge rule.
    BEST PRACTICE: set to false to pause instead of destroying the rule.
    This preserves the rule configuration.
  EOT
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.log_retention_days
    )
    error_message = "The value must be a valid CloudWatch retention period."
  }
}