# ─── CloudWatch Log Group ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7

  tags = { Name = "${var.project_name}-logs" }
}

# ─── Scale OUT: CPU > 60% → add more tasks ──────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_out_cpu_threshold

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_description = "Scale out when CPU usage exceeds ${var.scale_out_cpu_threshold}%"
  alarm_actions     = [aws_appautoscaling_policy.scale_out.arn]
}

# ─── Scale IN: CPU < 20% → remove tasks ─────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.project_name}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 3 # more conservative for scale-in
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.scale_in_cpu_threshold

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_description = "Scale in when CPU usage drops below ${var.scale_in_cpu_threshold}%"
  alarm_actions     = [aws_appautoscaling_policy.scale_in.arn]
}