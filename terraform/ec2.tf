data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

locals {
  user_data_vars = {
    app_port               = var.app_port
    environment            = var.environment
    git_repo_url           = var.git_repo_url
    git_branch             = var.git_branch
    database_url           = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.address}:${var.db_port}/${var.db_name}"
    secret_key_base        = var.secret_key_base
    domain_name            = var.domain_name
    bearer_token           = var.bearer_token
    whitelisted_domains    = var.whitelisted_domains
    google_credentials_json= var.google_credentials_json
    pool_size              = var.pool_size
  }
}

resource "aws_launch_template" "main" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  key_name      = "AvantiFellows"

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  vpc_security_group_ids = [aws_security_group.ec2.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", local.user_data_vars))
}

resource "aws_autoscaling_group" "main" {
  name                      = "${local.name_prefix}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = data.aws_subnets.default.ids
  health_check_grace_period = 300
  health_check_type         = "EC2"

  launch_template {
    id      = aws_launch_template.main.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.main.arn]

  # Instance refresh configuration for automatic rolling updates
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup       = 300
      skip_matching         = false
    }
    triggers = ["tag"]
  }

  # Tag that changes when user data or setup script changes to trigger refresh
  tag {
    key                 = "UserDataHash"
    value               = md5(join("", [
      templatefile("${path.module}/user_data.sh.tpl", local.user_data_vars),
      file("${path.module}/../scripts/setup.sh")
    ]))
    propagate_at_launch = false
  }

  # Environment tag
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  # Name tag for instances
  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}


