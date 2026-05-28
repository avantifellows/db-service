################################################################################
# Cluster
################################################################################

resource "aws_ecs_cluster" "this" {
  name = "db-service-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

################################################################################
# Task definition
################################################################################

locals {
  phx_host = "${var.domain_prefix}.avantifellows.org"
  image    = "${aws_ecr_repository.this.repository_url}:${var.image_tag}"

  container_env = [
    { name = "PHX_SERVER", value = "true" },
    { name = "PORT", value = tostring(var.app_port) },
    { name = "PHX_HOST", value = local.phx_host },
    { name = "POOL_SIZE", value = var.pool_size },
    { name = "WHITELISTED_DOMAINS", value = var.whitelisted_domains },
    { name = "CSV_BUCKET", value = aws_s3_bucket.csv_imports.bucket },
    { name = "DATABASE_URL", value = var.database_url },
    { name = "SECRET_KEY_BASE", value = var.secret_key_base },
    { name = "BEARER_TOKEN", value = var.bearer_token },
    { name = "GOOGLE_CREDENTIALS_JSON", value = var.google_credentials_json },
    { name = "DASHBOARD_USER", value = var.dashboard_user },
    { name = "DASHBOARD_PASS", value = var.dashboard_pass },
  ]
}

resource "aws_ecs_task_definition" "this" {
  family                   = "db-service-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name         = "db-service"
      image        = local.image
      essential    = true
      stopTimeout  = var.stop_timeout
      portMappings = [{ containerPort = var.app_port, protocol = "tcp" }]

      environment = local.container_env

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.app_port}/api/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

################################################################################
# Service
################################################################################

resource "aws_ecs_service" "this" {
  name             = "db-service-${var.environment}"
  cluster          = aws_ecs_cluster.this.id
  task_definition  = aws_ecs_task_definition.this.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "LATEST"

  enable_execute_command = true

  # Give the Phoenix release time to boot before the ALB starts failing the
  # task on health checks. Without this, a slow cold start gets killed.
  health_check_grace_period_seconds = 120

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "db-service"
    container_port   = var.app_port
  }

  # CI registers new task definition revisions on every deploy. Don't let
  # Terraform fight the deploy pipeline by trying to revert to the version
  # baked into state on the next apply.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [aws_lb_listener_rule.this]
}

################################################################################
# Auto-scaling
################################################################################

resource "aws_appautoscaling_target" "this" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "db-service-${var.environment}-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}
