# =============================================================================
# AWS Infrastructure for Skytrax Reviews dbt Project
# =============================================================================
# Resources are split by service:
#   - s3.tf   : S3 bucket for dbt artifacts (slim CI state comparison)
#   - vpc.tf  : VPC with public subnet for the dbt docs server
#   - iam.tf  : IAM role and instance profile for EC2 S3 access
#   - ec2.tf  : EC2 instance running nginx to serve dbt docs
# =============================================================================

# Get the current AWS account ID and region (avoids hardcoding)
data "aws_caller_identity" "current" {}
