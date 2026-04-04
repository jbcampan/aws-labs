variable "aws_region" {
    type = string

    default = "eu-west-3"
}

variable "mybucket" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "instance_type" {
    type = string
    default = "t3.micro"
}