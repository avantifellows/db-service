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

# ECS Exec (enable_execute_command = true on the service) needs the task role to
# hold these ssmmessages permissions; without them `aws ecs execute-command`
# fails. These actions don't support resource-level scoping, so "*" is required.
data "aws_iam_policy_document" "task_ecs_exec" {
  statement {
    sid    = "ECSExecSSMMessages"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "task_ecs_exec" {
  name   = "ecs-exec-ssm"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_ecs_exec.json
}

################################################################################
# CI deploy user — shared across envs; create once, then set the flag back to false
################################################################################

resource "aws_iam_user" "ci" {
  count = var.create_ci_user ? 1 : 0
  name  = "db-service-ci-deploy"

  # Once created, the user backs GitHub Secrets. Flipping create_ci_user back
  # to false must not silently delete it (and the access key the CI relies on).
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_access_key" "ci" {
  count = var.create_ci_user ? 1 : 0
  user  = aws_iam_user.ci[0].name
}

data "aws_caller_identity" "current" {}

locals {
  # Wildcards cover both env-prefixed resources (db-service-staging / -prod).
  _acct           = data.aws_caller_identity.current.account_id
  ci_ecr_repos    = "arn:aws:ecr:${var.aws_region}:${local._acct}:repository/db-service-*"
  ci_ecs_services = "arn:aws:ecs:${var.aws_region}:${local._acct}:service/db-service-*/db-service-*"
  ci_ecs_taskdefs = "arn:aws:ecs:${var.aws_region}:${local._acct}:task-definition/db-service-*:*"
  ci_ecs_tasks    = "arn:aws:ecs:${var.aws_region}:${local._acct}:task/db-service-*/*"
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
    resources = [local.ci_ecr_repos]
  }

  statement {
    sid    = "ECSServiceDeploy"
    effect = "Allow"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [local.ci_ecs_services]
  }

  statement {
    sid       = "ECSRunTask"
    effect    = "Allow"
    actions   = ["ecs:RunTask"]
    resources = [local.ci_ecs_taskdefs]
  }

  statement {
    sid    = "ECSTaskControl"
    effect = "Allow"
    actions = [
      "ecs:StopTask",
      "ecs:DescribeTasks",
    ]
    resources = [local.ci_ecs_tasks]
  }

  # These ECS actions don't support resource-level permissions (AWS IAM
  # limitation), so they must stay on "*", scoped only by action.
  statement {
    sid    = "ECSGlobalReadRegister"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:ListTasks",
    ]
    resources = ["*"]
  }

  # Needed by the deploy workflow to resolve the task security group/subnets
  # for the one-off migration RunTask, and to smoke-check via the ALB.
  statement {
    sid    = "Discovery"
    effect = "Allow"
    actions = [
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
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
