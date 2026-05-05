variable "lab_name" {
  type = string
  description = "Name of the lab project"

  default = "lab-02-api-rest"
}

variable "aws_region" {
  type = string
  description = "Region AWS"

  default = "eu-west-3"
}

variable "table_name" {
  type = string
  description = "Name of the DynamoDB table"

  default = "items"
}