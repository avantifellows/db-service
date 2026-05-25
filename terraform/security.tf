data "aws_lb" "shared" {
  name = var.alb_name
}

resource "aws_security_group" "tasks" {
  name        = "db-service-${var.environment}-sg"
  description = "Inbound from shared ALB on app port; egress all (RDS, S3, ECR, Goth)."
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB → tasks: only the ALB's security group(s) may reach the container port.
resource "aws_security_group_rule" "tasks_ingress_from_alb" {
  for_each = toset(data.aws_lb.shared.security_groups)

  type                     = "ingress"
  from_port                = var.app_port
  to_port                  = var.app_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  security_group_id        = aws_security_group.tasks.id
  description              = "ALB to ECS task on app port"
}
