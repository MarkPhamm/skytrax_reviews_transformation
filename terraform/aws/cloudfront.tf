# =============================================================================
# CloudFront Distribution -- dbt Docs Hosting
# =============================================================================
# Serves dbt docs directly from the S3 bucket's docs/ prefix.
# No EC2 server needed -- CloudFront caches and serves the static files.
# Updates are instant: the CD pipeline uploads docs to S3, then invalidates
# the CloudFront cache so the latest docs are always available.

# --- Origin Access Control ---
# Allows CloudFront to read from S3 without making the bucket public.

resource "aws_cloudfront_origin_access_control" "docs" {
  name                              = "${var.project_name}-docs-oac"
  description                       = "OAC for dbt docs S3 origin"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# --- CloudFront Distribution ---

resource "aws_cloudfront_distribution" "docs" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "dbt docs for ${var.project_name}"

  origin {
    domain_name              = aws_s3_bucket.dbt_artifacts.bucket_regional_domain_name
    origin_id                = "s3-dbt-docs"
    origin_path              = "/docs"
    origin_access_control_id = aws_cloudfront_origin_access_control.docs.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-dbt-docs"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    # Cache for 5 minutes -- balance between freshness and performance
    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-docs-cdn"
  }
}

# --- S3 Bucket Policy ---
# Allow CloudFront to read objects from the bucket via OAC.

resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.dbt_artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.dbt_artifacts.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.docs.arn
          }
        }
      }
    ]
  })
}
