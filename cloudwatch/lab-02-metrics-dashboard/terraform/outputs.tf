output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.lab02.id
}

output "instance_public_ip" {
  description = "IP publique de l'instance (si assignée)"
  value       = aws_instance.lab02.public_ip
}

output "instance_private_ip" {
  description = "IP privée de l'instance"
  value       = aws_instance.lab02.private_ip
}

output "dashboard_url" {
  description = "URL directe vers le dashboard CloudWatch"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.lab02.dashboard_name}"
}

output "ssm_connect_command" {
  description = "Commande pour se connecter à l'instance via SSM Session Manager (sans SSH)"
  value       = "aws ssm start-session --target ${aws_instance.lab02.id} --region ${var.aws_region}"
}

output "check_agent_command" {
  description = "Commande SSM pour vérifier l'état de l'agent CloudWatch"
  value       = "aws ssm send-command --instance-ids ${aws_instance.lab02.id} --document-name AWS-RunShellScript --parameters commands='systemctl status amazon-cloudwatch-agent' --region ${var.aws_region}"
}

output "cpu_alarm_arn" {
  description = "ARN de l'alarme CPU"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

output "ram_alarm_arn" {
  description = "ARN de l'alarme RAM"
  value       = aws_cloudwatch_metric_alarm.ram_high.arn
}

output "cloudwatch_agent_config_path" {
  description = "Chemin du paramètre SSM contenant la config de l'agent"
  value       = aws_ssm_parameter.cloudwatch_agent_config.name
}

output "custom_metrics_namespace" {
  description = "Namespace CloudWatch des métriques custom (RAM, disque)"
  value       = "Lab02/EC2"
}

output "aws_region" {
  value = var.aws_region
}