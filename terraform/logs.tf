resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/db-service-${var.environment}"
  retention_in_days = var.log_retention_days
}
