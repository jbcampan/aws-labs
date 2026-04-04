variable "users" {
  description = "Map des utilisateurs et leur groupe"
  type        = map(string)

  default = {
    user1 = "developers"
    user2 = "developers"
    user3 = "readonly"
  }
}

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