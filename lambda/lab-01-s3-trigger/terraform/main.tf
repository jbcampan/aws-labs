###############################
# Datas
###############################
data "aws_caller_identity" "current" {}


###############################
# Locals
###############################
locals {
  common_tags = {
    Project     = var.project_name
    Environment = "lab"
    ManagedBy   = "terraform"
  }
}
