######################################
# SNS Topic
######################################
resource "aws_sns_topic" "alerts" {
  name = "lab02-alerts"
}

######################################
# SNS Topic subscription
######################################
resource "aws_sns_topic_subscription" "cpu" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


# ==============================================================
# CLOUDWATCH DASHBOARD
# ==============================================================
# The dashboard is defined in JSON. Each widget has:
#   - type       : "metric" | "text" | "alarm"
#   - properties : metric configuration, period, statistic, title, etc.
#   - x, y       : position in the grid (width = 24 columns)
#   - width, height : dimensions in grid units

resource "aws_cloudwatch_dashboard" "lab02" {
  dashboard_name = "lab02-metrics-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      # ── Widget text : title and context ─────────────────
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "# 🖥️ Lab-02 — Metrics Dashboard\n**Instance :** `${aws_instance.lab02.id}` | **Région :** `${var.aws_region}` | **Type :** `${var.instance_type}`\n\n> Les métriques **CPU/Réseau/Disque I/O** viennent d'AWS natif. La **RAM** et l'**espace disque** viennent de l'agent CloudWatch (namespace `Lab02/EC2`)."
        }
      },

      # ── Line 1 : CPU ─────────────────────────────────────

      # -------------------------------------------------------
      # Source  : AWS/EC2 (native metric, no agent required)
      # Period  : 300s (basic monitoring granularity)
      # Format  : ["namespace", "metric_name", "dimension_key", "dimension_value"]
      # -------------------------------------------------------
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization — AWS Native (5 min)"
          view   = "timeSeries"
          stacked = false
          period = 300
          stat   = "Average"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization",
              "InstanceId", aws_instance.lab02.id,
              { label = "CPU %", color = "#ff6b6b", yAxis = "left" }
            ]
          ]
          yAxis = {
            left = { min = 0, max = 100, label = "%" }
          }
          annotations = {
            horizontal = [
              { label = "Alarm 80%", value = 80, color = "#ff0000" }
            ]
          }
        }
      },

      # -------------------------------------------------------
      # CPU Utilization (Detailed Monitoring)
      # Source  : AWS/EC2 (detailed monitoring enabled, 1-minute granularity)
      # Period  : 60s (high-resolution metrics for faster detection)
      # -------------------------------------------------------
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title  = "CPU Utilization — Detailed Monitoring (1 min)"
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "CPUUtilization",
              "InstanceId", aws_instance.lab02.id,
              { label = "CPU % (1min)", color = "#ff9f43" }
            ]
          ]
          yAxis = {
            left = { min = 0, max = 100, label = "%" }
          }
          annotations = {
            horizontal = [
              { label = "Alarme 80%", value = 80, color = "#ff0000" }
            ]
          }
        }
      },

      # ── Line 2: Memory & Disk Usage (CW Agent) ──────────────

      # -------------------------------------------------------
      # Source  : CWAgent (custom metrics — requires CloudWatch Agent installed)
      # AWS does not provide memory or disk metrics natively because
      # the hypervisor layer has no visibility into the guest OS.
      # These metrics are collected from inside the instance via the agent.
      # Period  : 60s (high-resolution monitoring, agent-based collection)
      # Format  : ["namespace", "metric_name", "dimension_key", "dimension_value"]
      # -------------------------------------------------------

      # Used memory in %
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "RAM Used % — CloudWatch Agent"
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          region = var.aws_region
          metrics = [
            ["Lab02/EC2", "mem_used_percent",
              "InstanceId", aws_instance.lab02.id,
              { label = "RAM %", color = "#54a0ff" }
            ]
          ]
          yAxis = {
            left = { min = 0, max = 100, label = "%" }
          }
        }
      },

      # Available memory in MB
      {
        type   = "metric"
        x      = 8
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "RAM Available — CloudWatch Agent"
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          region = var.aws_region
          metrics = [
            ["Lab02/EC2", "mem_available",
              "InstanceId", aws_instance.lab02.id,
              { label = "RAM available (bytes)", color = "#1dd1a1" }
            ]
          ]
          yAxis = {
            left = { label = "bytes" }
          }
        }
      },

      # Disk space / in %
      {
        type   = "metric"
        x      = 16
        y      = 8
        width  = 8
        height = 6
        properties = {
          title  = "Disk Used % (/) — CloudWatch Agent"
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          region = var.aws_region
          metrics = [
            ["Lab02/EC2", "disk_used_percent",
              "InstanceId", aws_instance.lab02.id,
              "path", "/",
              "device", "xvda1",
              "fstype", "xfs",
              { label = "Disk %", color = "#feca57" }
            ]
          ]
          yAxis = {
            left = { min = 0, max = 100, label = "%" }
          }
        }
      },

      # ── Line 3 : Network In / Out ──────────────────────────────────

      # -------------------------------------------------------
      # Source  : AWS/EC2 (native metric, no agent required)
      # Period  : 300s — stat is Sum (total bytes/packets over time window)
      # Note    : These metrics are cumulative counters, not instantaneous rates.
      # Format  : ["namespace", "metric_name", "dimension_key", "dimension_value"]
      # -------------------------------------------------------

      # Network In/Out
      {
        type   = "metric"
        x      = 0
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "Network In/Out — AWS Native"
          view   = "timeSeries"
          period = 300
          stat   = "Sum"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkIn",
              "InstanceId", aws_instance.lab02.id,
              { label = "Network In (bytes)", color = "#00d2d3" }
            ],
            ["AWS/EC2", "NetworkOut",
              "InstanceId", aws_instance.lab02.id,
              { label = "Network Out (bytes)", color = "#ff9ff3" }
            ]
          ]
        }
      },

      # Network packets
      {
        type   = "metric"
        x      = 12
        y      = 14
        width  = 12
        height = 6
        properties = {
          title  = "Network Packets In/Out — AWS Native"
          view   = "timeSeries"
          period = 300
          stat   = "Sum"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "NetworkPacketsIn",
              "InstanceId", aws_instance.lab02.id,
              { label = "Packets In", color = "#48dbfb" }
            ],
            ["AWS/EC2", "NetworkPacketsOut",
              "InstanceId", aws_instance.lab02.id,
              { label = "Packets Out", color = "#ff9ff3" }
            ]
          ]
        }
      },

      # ── Line 4 : Disk I/O (native) ────────────────────────

      # Disk Read/Write Bytes (I/O physique — natif AWS)
      {
        type   = "metric"
        x      = 0
        y      = 20
        width  = 12
        height = 6
        properties = {
          title  = "Disk I/O Bytes — AWS Native"
          view   = "timeSeries"
          period = 300
          stat   = "Sum"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "DiskReadBytes",
              "InstanceId", aws_instance.lab02.id,
              { label = "Disk Read (bytes)", color = "#5f27cd" }
            ],
            ["AWS/EC2", "DiskWriteBytes",
              "InstanceId", aws_instance.lab02.id,
              { label = "Disk Write (bytes)", color = "#341f97" }
            ]
          ]
        }
      },

      # Disk Read/Write Ops
      {
        type   = "metric"
        x      = 12
        y      = 20
        width  = 12
        height = 6
        properties = {
          title  = "Disk I/O Operations — AWS Native"
          view   = "timeSeries"
          period = 300
          stat   = "Sum"
          region = var.aws_region
          metrics = [
            ["AWS/EC2", "DiskReadOps",
              "InstanceId", aws_instance.lab02.id,
              { label = "Read Ops", color = "#a29bfe" }
            ],
            ["AWS/EC2", "DiskWriteOps",
              "InstanceId", aws_instance.lab02.id,
              { label = "Write Ops", color = "#6c5ce7" }
            ]
          ]
        }
      },

      # ── Line 5 : Processus (CW Agent) ───────────────────

      {
        type   = "metric"
        x      = 0
        y      = 26
        width  = 12
        height = 6
        properties = {
          title  = "Processus — CloudWatch Agent"
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          region = var.aws_region
          metrics = [
            ["Lab02/EC2", "processes_running",
              "InstanceId", aws_instance.lab02.id,
              { label = "Running", color = "#00b894" }
            ],
            ["Lab02/EC2", "processes_sleeping",
              "InstanceId", aws_instance.lab02.id,
              { label = "Sleeping", color = "#fdcb6e" }
            ],
            ["Lab02/EC2", "processes_total",
              "InstanceId", aws_instance.lab02.id,
              { label = "Total", color = "#636e72" }
            ]
          ]
        }
      },

      # Widget alarm CPU
      {
        type   = "alarm"
        x      = 12
        y      = 26
        width  = 12
        height = 6
        properties = {
          title  = "Alarms state"
          alarms = [aws_cloudwatch_metric_alarm.cpu_high.arn]
        }
      }
    ]
  })
}

# ==============================================================
# CLOUDWATCH ALARM — CPU > 80%
# ==============================================================

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "lab02-cpu-high"
  alarm_description   = "CPU > 80% for 2 consecutive 5-minute periods"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  evaluation_periods  = 2     # Triggers after 2 alarm periods (avoids false positives)
  datapoints_to_alarm = 2     # Both datapoints must exceed the threshold
  period              = 300   # 5-minute period (basic monitoring)
  statistic           = "Average"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"

  dimensions = {
    InstanceId = aws_instance.lab02.id
  }

  # If no data → no alarm (safer behavior than ALARM)
  treat_missing_data = "notBreaching"

  # SNS notification (lab-01) — optional if no SNS topic is defined
  alarm_actions = [aws_sns_topic.alerts.arn]
  # ok_actions = [aws_sns_topic.alerts.arn]         # optional: notification when the alarm returns to OK state

  tags = {
    Name = "lab02-cpu-alarm"
  }
}

# ==============================================================
# CLOUDWATCH ALARM — RAM > 85%
# ==============================================================
# Custom metric → Lab02/EC2 namespace, requires the agent

resource "aws_cloudwatch_metric_alarm" "ram_high" {
  alarm_name          = "lab02-ram-high"
  alarm_description   = "RAM usage > 85% for 3 periods of 1 minute"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 85
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  period              = 60
  statistic           = "Average"

  namespace   = "Lab02/EC2"
  metric_name = "mem_used_percent"

  dimensions = {
    InstanceId = aws_instance.lab02.id
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  # ok_actions = [aws_sns_topic.alerts.arn]         # optional: notification when the alarm returns to OK state

  tags = {
    Name = "lab02-ram-alarm"
  }
}
