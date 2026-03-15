# =============================================================================
# S3 Bucket -- dbt Artifacts
# =============================================================================
# Stores manifest.json, run_results.json, and compiled SQL.
# Used by dbt slim CI to compare production state with PR changes
# (dbt build --select state:modified+).

resource "aws_s3_bucket" "dbt_artifacts" {
  bucket = var.artifacts_bucket_name

  tags = {
    Name = "${var.project_name}-dbt-artifacts"
  }
}

# Enable versioning so we can recover previous artifact states
resource "aws_s3_bucket_versioning" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt everything at rest with AWS-managed keys (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access -- these artifacts are internal only
resource "aws_s3_bucket_public_access_block" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Clean up old artifact versions after 30 days to save storage costs
resource "aws_s3_bucket_lifecycle_configuration" "dbt_artifacts" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
