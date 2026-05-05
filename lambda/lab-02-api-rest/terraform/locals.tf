# ############################
# Centralized config
# ############################
locals {
  lambdas = {
    create = {
      action = "dynamodb:PutItem"
      file   = "create_item.py"
      route  = "POST /items"
    }
    read = {
      action = "dynamodb:GetItem"
      file   = "read_item.py"
      route  = "GET /items/{id}"
    }
    update = {
      action = "dynamodb:UpdateItem"
      file   = "update_item.py"
      route  = "PUT /items/{id}"
    }
    delete = {
      action = "dynamodb:DeleteItem"
      file   = "delete_item.py"
      route  = "DELETE /items/{id}"
    }
  }
}