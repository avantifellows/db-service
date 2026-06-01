resource "aws_s3_bucket" "csv_imports" {
  bucket = "db-service-${var.environment}-csv-imports"
}

resource "aws_s3_bucket_public_access_block" "csv_imports" {
  bucket = aws_s3_bucket.csv_imports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "csv_imports" {
  bucket = aws_s3_bucket.csv_imports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "csv_imports" {
  bucket = aws_s3_bucket.csv_imports.id

  rule {
    id     = "expire-old-imports"
    status = "Enabled"

    # CSV imports are processed within minutes; keep them around for 30 days
    # for audit/debugging then expire to control storage cost.
    expiration {
      days = 30
    }

    filter {}
  }
}
