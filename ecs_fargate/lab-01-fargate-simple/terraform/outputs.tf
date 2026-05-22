###############################################################################
# Outputs — valeurs utiles après le déploiement
###############################################################################

output "ecr_repository_url" {
  description = "URL du repository ECR pour docker push"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_registry" {
  description = "Registry ECR (pour docker login)"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

output "ecs_cluster_name" {
  description = "Nom du cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "Nom du service ECS"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group" {
  description = "Groupe de logs CloudWatch"
  value       = aws_cloudwatch_log_group.app.name
}

output "aws_region" {
  description = "Région AWS utilisée"
  value       = data.aws_region.current.name
}

# Commandes utiles générées automatiquement avec les bonnes valeurs
output "commands" {
  description = "Commandes utiles pour interagir avec le lab"
  value = {
    docker_login = "aws ecr get-login-password --region ${data.aws_region.current.name} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"

    docker_build = "docker build -t ${var.project_name}-app ./app"

    docker_tag = "docker tag ${var.project_name}-app:latest ${aws_ecr_repository.app.repository_url}:latest"

    docker_push = "docker push ${aws_ecr_repository.app.repository_url}:latest"

    list_tasks = "aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${aws_ecs_service.app.name} --region ${data.aws_region.current.name}"

    describe_tasks = "aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --region ${data.aws_region.current.name} --tasks $(aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${aws_ecs_service.app.name} --region ${data.aws_region.current.name} --query 'taskArns[0]' --output text)"

    force_redeploy = "aws ecs update-service --cluster ${aws_ecs_cluster.main.name} --service ${aws_ecs_service.app.name} --force-new-deployment --region ${data.aws_region.current.name}"

    view_logs = "aws logs tail ${aws_cloudwatch_log_group.app.name} --follow --region ${data.aws_region.current.name}"
  }
}
