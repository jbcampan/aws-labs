output "alb_dns_name" {
  description = "DNS name of the ALB — access the application through this URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL used to push the Docker image"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.ecs.name
}

# Added to outputs.tf so bash scripts can retrieve the AWS region
output "aws_region" {
  description = "AWS region in use"
  value       = var.aws_region
}