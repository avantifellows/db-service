output "ecr_repository_url" {
  description = "Push images here (CI uses this)."
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name (CI uses this)."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name (CI uses this for update-service)."
  value       = aws_ecs_service.this.name
}

output "ecs_task_definition_family" {
  description = "Task definition family (CI uses this for describe-task-definition)."
  value       = aws_ecs_task_definition.this.family
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.app.name
}

output "csv_bucket_name" {
  value = aws_s3_bucket.csv_imports.bucket
}

output "service_url" {
  value = "https://${var.domain_prefix}.avantifellows.org"
}

output "task_subnets" {
  description = "Subnet IDs ECS tasks run in (used by CI run-task for migrations)."
  value       = var.subnet_ids
}

output "task_security_group_id" {
  description = "Security group ID for migration tasks (used by CI run-task)."
  value       = aws_security_group.tasks.id
}

output "ci_access_key_id" {
  description = "CI deploy user access key ID. Only set when create_ci_user = true."
  value       = var.create_ci_user ? aws_iam_access_key.ci[0].id : null
}

output "ci_secret_access_key" {
  description = "CI deploy user secret access key. Only set when create_ci_user = true."
  value       = var.create_ci_user ? aws_iam_access_key.ci[0].secret : null
  sensitive   = true
}
