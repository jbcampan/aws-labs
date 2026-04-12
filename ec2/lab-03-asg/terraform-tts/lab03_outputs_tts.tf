######################################
# ALB
######################################
output "alb_dns_name" {
  description = "ALB public DNS — paste into the browser to test"
  value       = aws_lb.alb.dns_name
}

output "alb_arn" {
  description = "ARN de l'ALB"
  value       = aws_lb.alb.arn
}

######################################
# ASG
######################################
output "asg_name" {
  description = "Auto Scaling Group name — used by the stress test"
  value       = aws_autoscaling_group.asg.name
}

output "asg_min_size" {
  description = "Configured minimum capacity"
  value       = aws_autoscaling_group.asg.min_size
}

output "asg_desired_capacity" {
  description = "Desired capacity at deployment"
  value       = aws_autoscaling_group.asg.desired_capacity
}

output "asg_max_size" {
  description = "Maximum allowed capacity"
  value       = aws_autoscaling_group.asg.max_size
}

######################################
# Scaling policy
######################################
output "scaling_policy_name" {
  description = "Target tracking policy name"
  value       = aws_autoscaling_policy.cpu_target_tracking.name
}

output "cpu_target_value" {
  description = "Target tracking CPU target (%)"
  value       = var.cpu_target_value
}

######################################
# Target Group
######################################
output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.tg.arn
}

######################################
# Launch Template
######################################
output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.lt.id
}

output "launch_template_latest_version" {
  description = "Last version of the Launch Template"
  value       = aws_launch_template.lt.latest_version
}

######################################
# Network
######################################
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the publics subnets (AZ-a et AZ-b)"
  value       = module.vpc.public_subnet_ids
}

######################################
# IAM
######################################
output "instance_profile_name" {
  description = "IAM instance profile name attached to instances"
  value       = aws_iam_instance_profile.ec2_profile.name
}

######################################
# Useful commands
######################################
output "test_alb_command" {
  description = "Curl command to test the ALB"
  value       = "curl http://${aws_lb.alb.dns_name}"
}

output "watch_asg_command" {
  description = "Command to monitor ASG instances in real time"
  value       = "watch -n 5 'aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.asg.name} --region ${var.region} --query \"AutoScalingGroups[0].Instances[*].{ID:InstanceId,AZ:AvailabilityZone,State:LifecycleState,Health:HealthStatus}\" --output table'"
}

output "watch_alarms_command" {
  description = "Monitor CloudWatch alarms automatically created by Target Tracking"
  value       = "watch -n 10 'aws cloudwatch describe-alarms --alarm-name-prefix TargetTracking-lab03-asg --region ${var.region} --query \"MetricAlarms[*].{Name:AlarmName,State:StateValue}\" --output table'"
}

output "stress_test_hint" {
  description = "Reminder — run the stress test from the script/ directory"
  value       = "bash ../script/stress-test.sh"
}
