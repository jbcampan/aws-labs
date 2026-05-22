###############################################################################
# ECR — Elastic Container Registry
# AWS private Docker registry where you push your application image
###############################################################################

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE" # Allows overwriting the "latest" tag

  image_scanning_configuration {
    scan_on_push = true # Automatically scans images for vulnerabilities on each push
  }

}

# Lifecycle policy: keep only the 5 most recent untagged images
# Helps avoid paying for unnecessary ECR storage
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the 5 most recent untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = { type = "expire" }
      }
    ]
  })
}