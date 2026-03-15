# =============================================================================
# AWS Infrastructure for Skytrax Reviews dbt Project
# =============================================================================
# Resources are split by service:
#   - s3.tf          : S3 bucket for dbt artifacts (slim CI state comparison)
#   - cloudfront.tf  : CloudFront distribution for dbt docs hosting
#   - iam.tf         : GitHub Actions OIDC for CI/CD
#   - vpc.tf.disabled / ec2.tf.disabled : EC2 approach (replaced by CloudFront)
# =============================================================================

# Get the current AWS account ID and region (avoids hardcoding)
data "aws_caller_identity" "current" {}
