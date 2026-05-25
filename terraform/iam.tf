################################################################################
# Task execution role — used by ECS to pull images and write logs
################################################################################

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "db-service-${var.environment}-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################################################################
# Task role — IAM identity the container itself runs under
################################################################################

resource "aws_iam_role" "task" {
  name               = "db-service-${var.environment}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# S3 access scoped to this environment's CSV imports bucket only.
data "aws_iam_policy_document" "task_s3" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.csv_imports.arn]
  }

  statement {
    sid    = "ObjectAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.csv_imports.arn}/*"]
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name   = "csv-imports-bucket"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_s3.json
}

################################################################################
# CI deploy user — shared across envs; create once, then set the flag back to false
################################################################################

resource "aws_iam_user" "ci" {
  count = var.create_ci_user ? 1 : 0
  name  = "db-service-ci-deploy"
}

resource "aws_iam_access_key" "ci" {
  count = var.create_ci_user ? 1 : 0
  user  = aws_iam_user.ci[0].name
}

data "aws_iam_policy_document" "ci_policy" {
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages",
    ]
    resources = ["*"] # both env-prefixed repos
  }

  statement {
    sid    = "ECSDeploy"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:RunTask",
      "ecs:DescribeTasks",
      "ecs:ListTasks",
      "ecs:StopTask",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PassRoles"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      aws_iam_role.task_execution.arn,
      aws_iam_role.task.arn,
    ]
  }

  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.app.arn}:*"]
  }
}

resource "aws_iam_user_policy" "ci" {
  count  = var.create_ci_user ? 1 : 0
  name   = "deploy"
  user   = aws_iam_user.ci[0].name
  policy = data.aws_iam_policy_document.ci_policy.json
}
