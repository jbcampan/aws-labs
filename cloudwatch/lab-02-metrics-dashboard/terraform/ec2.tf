# ==============================================================
# CONFIG CLOUDWATCH AGENT (stored in SSM Parameter Store)
# ==============================================================
# We store the JSON configuration in SSM: the agent will read it at startup.
# Advantage: no need to recreate the instance to change the configuration.

resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name  = "/lab02/cloudwatch-agent/config"
  type  = "String"
  value = local.cloudwatch_agent_config

  tags = {
    Name = "lab02-cloudwatch-agent-config"
  }
}

locals {
  cloudwatch_agent_config = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                 = "root"
    }

    metrics = {
      namespace = "Lab02/EC2"

      # Aggregated metrics (all dimensions combined)
      aggregation_dimensions = [["InstanceId"]]

      metrics_collected = {
        # ── RAM Memory ─────────────────────────────────────
        # Does NOT exist natively: AWS cannot see inside the OS
        mem = {
          measurement = [
            "mem_used_percent",
            "mem_used",
            "mem_available"
          ]
          metrics_collection_interval = 60
        }

        # ── Disk space ────────────────────────────────────
        # Same: the hypervisor does not know the file systems
        disk = {
          measurement = [
            "disk_used_percent",
            "disk_used",
            "disk_free"
          ]
          resources                   = ["/"]
          metrics_collection_interval = 60
        }

        # ── Detailed CPU (complement to native metrics) ──
        cpu = {
          measurement = [
            "cpu_usage_idle",
            "cpu_usage_user",
            "cpu_usage_system"
          ]
          metrics_collection_interval = 60
          totalcpu                    = true
        }

        # ── Processus ────────────────────────────────────────
        processes = {
          measurement = [
            "running",
            "sleeping",
            "total"
          ]
          metrics_collection_interval = 60
        }
      }
    }

    # Log collection (optional — useful for debugging)
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path        = "/var/log/amazon/amazon-cloudwatch-agent/amazon-cloudwatch-agent.log"
              log_group_name   = "/lab02/cloudwatch-agent"
              log_stream_name  = "{instance_id}"
              retention_in_days = 7
            },
            {
              file_path        = "/var/log/messages"
              log_group_name   = "/lab02/system"
              log_stream_name  = "{instance_id}"
              retention_in_days = 7
            }
          ]
        }
      }
    }
  })
}

# ==============================================================
# EC2 INSTANCE
# ==============================================================

resource "aws_instance" "lab02" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.lab02.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_cloudwatch.name
  key_name               = var.key_pair_name != "" ? var.key_pair_name : null

  # Detailed native EC2 monitoring (1-minute granularity instead of 5 minutes)
  # Note: paid outside the free tier (~$3.50/instance/month in production
  monitoring = true

  user_data                   = file("${path.module}/../script/cloudwatch-agent.sh")
  user_data_replace_on_change = true

  tags = {
    Name = "lab02-metrics-instance"
  }

  # Explicit dependency: the instance must start after the SSM configuration
  depends_on = [aws_ssm_parameter.cloudwatch_agent_config]
}
