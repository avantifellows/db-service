# IAM Role and Policy for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name_prefix = "${local.environment_prefix}ec2_role" # Creates environment-specific role name

  assume_role_policy = jsonencode({ # Policy allowing EC2 to assume this role
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
      },
    ]
  })
}

# Attaches SSM read-only access policy to the EC2 role
resource "aws_iam_role_policy_attachment" "ec2_elb_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Attaches CloudWatch agent policy to allow EC2 instances to send metrics
resource "aws_iam_role_policy_attachment" "ec2_describe_ec2" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attaches CloudWatch logs policy for EC2 log management
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_logs" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Creates an instance profile to attach the IAM role to EC2 instances
resource "aws_iam_instance_profile" "ec2_profile" {
  name_prefix = "${local.environment_prefix}ec2_profile"
  role        = aws_iam_role.ec2_role.name
}

# ASG with launch template
resource "aws_launch_template" "ec2_launch_templ" {
  name_prefix   = "${local.environment_prefix}ec2_launch_templ"
  image_id      = "ami-05e00961530ae1b55" # Ubuntu AMI ID
  instance_type = local.env_config.instance_type

  user_data = base64encode(templatefile("user_data.sh.tpl", { # Bootstrap script with environment variables
    # Template variables
    LOG_FILE              = "/var/log/user_data.log"
    BRANCH_NAME_TO_DEPLOY = data.dotenv.env_file.env["BRANCH_NAME_TO_DEPLOY"]
    TARGET_GROUP_NAME     = aws_lb_target_group.alb_tg.name
    environment_prefix    = local.environment_prefix
    DATABASE_URL          = data.dotenv.env_file.env["DATABASE_URL"]
    SECRET_KEY_BASE       = data.dotenv.env_file.env["SECRET_KEY_BASE"]
    POOL_SIZE             = data.dotenv.env_file.env["POOL_SIZE"]
    BEARER_TOKEN          = data.dotenv.env_file.env["BEARER_TOKEN"]
    PORT                  = data.dotenv.env_file.env["PORT"]
  }))

  network_interfaces { # Network configuration for instances
    associate_public_ip_address = false
    subnet_id                   = aws_subnet.subnet_2.id
    security_groups             = [aws_security_group.sg_for_ec2.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      local.common_tags,
      {
        Name = "${local.environment_prefix}ec2"
      }
    )
  }

  key_name = "AvantiFellows"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "optional"
  }
}

# Creates an Auto Scaling Group using the launch template
resource "aws_autoscaling_group" "asg" {
  name_prefix      = "${local.environment_prefix}asg"
  desired_capacity = local.env_config.desired_size
  max_size         = local.env_config.max_size
  min_size         = local.env_config.min_size

  target_group_arns   = [aws_lb_target_group.alb_tg.arn]
  vpc_zone_identifier = [aws_subnet.subnet_2.id]

  launch_template {
    id      = aws_launch_template.ec2_launch_templ.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name = "${local.environment_prefix}asg-instance"
      }
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# CloudWatch alarm to monitor CPU utilization
resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "${local.environment_prefix}high-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = local.environment == "production" ? "60" : "120"
  statistic           = "Average"
  threshold           = local.environment == "production" ? "70" : "80"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitors high CPU utilization on EC2 instances"
  alarm_actions     = [aws_autoscaling_policy.high_cpu_policy.arn]

  tags = local.common_tags
}

# Auto Scaling policy triggered by the CPU alarm
resource "aws_autoscaling_policy" "high_cpu_policy" {
  name                   = "${local.environment_prefix}high-cpu-policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = local.environment == "production" ? "300" : "600" # Shorter cooldown in production
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Bastion Host Instance
resource "aws_instance" "bastion_host" {
  ami             = "ami-05e00961530ae1b55"
  instance_type   = "t2.micro"
  key_name        = "AvantiFellows"
  subnet_id       = aws_subnet.subnet_1.id # Place in a public subnet
  security_groups = [aws_security_group.sg_bastion.id]

  tags = {
    Name = "${local.environment_prefix}Bastion-Host"
  }

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  provisioner "file" {
    source      = local.pem_file_path
    destination = "/home/ubuntu/AvantiFellows.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ubuntu/AvantiFellows.pem"
    ]
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("C:/Users/amanb/.ssh/AvantiFellows.pem")
    host        = self.public_ip
  }

  provisioner "local-exec" {
    command = "aws ec2 stop-instances --instance-ids ${self.id} --region ap-south-1"
    when    = create
  }
}
