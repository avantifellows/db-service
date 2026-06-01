resource "aws_ecr_repository" "this" {
  name                 = "db-service-${var.environment}"
  image_tag_mutability = "MUTABLE"

  # Allow `terraform destroy` to remove the repo even when it still holds
  # images pushed by the deploy pipeline.
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 20 images, expire the rest"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
