# =============================================================================
# IAM Role for EC2 -- S3 Read Access
# =============================================================================
# The docs server needs to pull dbt docs from S3. We use an instance profile
# instead of embedding AWS credentials on the machine.

resource "aws_iam_role" "docs_server" {
  name = "${var.project_name}-docs-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-docs-server-role"
  }
}

resource "aws_iam_role_policy" "docs_server_s3_read" {
  name = "${var.project_name}-s3-read"
  role = aws_iam_role.docs_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dbt_artifacts.arn,
          "${aws_s3_bucket.dbt_artifacts.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "docs_server" {
  name = "${var.project_name}-docs-server-profile"
  role = aws_iam_role.docs_server.name
}
