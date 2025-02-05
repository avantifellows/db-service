# Create the CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "${local.environment}-dbservice"
  retention_in_days = 30
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.environment_prefix}log-group"
    }
  )
}

# Create an IAM policy for CloudWatch Logs
resource "aws_iam_policy" "cloudwatch_logs_policy" {
  name        = "${local.environment_prefix}cloudwatch-logs-policy"
  description = "IAM policy for CloudWatch Logs access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.app_logs.arn}",
          "${aws_cloudwatch_log_group.app_logs.arn}:*"
        ]
      }
    ]
  })
}

# Attach the CloudWatch Logs policy to the EC2 role
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs_policy.arn
}

# Create SSM Parameter for CloudWatch Agent config
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name  = "${local.environment_prefix}cloudwatch-agent-config"
  type  = "String"
  tier  = "Standard"
  value = jsonencode({
    agent = {
      metrics_collection_interval = 60
      run_as_user                = "root"
    }
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path         = "/home/ubuntu/db-service/logs/info.log*"
              log_group_name    = "${local.environment}-dbservice"
              log_stream_name   = "{instance_id}"
              retention_in_days = 30
            }
          ]
        }
      }
    }
    metrics = {
      aggregation_dimensions  = [["InstanceId"]]
      append_dimensions = {
        AutoScalingGroupName = "$${aws:AutoScalingGroupName}"
        ImageId             = "$${aws:ImageId}"
        InstanceId          = "$${aws:InstanceId}"
        InstanceType        = "$${aws:InstanceType}"
      }
      metrics_collected = {
        disk = {
          measurement               = ["used_percent"]
          metrics_collection_interval = 60
          resources                 = ["*"]
        }
        mem = {
          measurement               = ["mem_used_percent"]
          metrics_collection_interval = 60
        }
      }
    }
  })

  tags = local.common_tags
}