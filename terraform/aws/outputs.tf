# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "artifacts_bucket_name" {
  description = "S3 bucket name for dbt artifacts"
  value       = aws_s3_bucket.dbt_artifacts.id
}

output "artifacts_bucket_arn" {
  description = "S3 bucket ARN for dbt artifacts (use in CI/CD IAM policies)"
  value       = aws_s3_bucket.dbt_artifacts.arn
}

# --- CloudFront ---

output "docs_cloudfront_domain" {
  description = "CloudFront domain for dbt docs -- visit https://<this-domain> to view docs"
  value       = aws_cloudfront_distribution.docs.domain_name
}

output "docs_cloudfront_distribution_id" {
  description = "CloudFront distribution ID -- used for cache invalidation in CD pipeline"
  value       = aws_cloudfront_distribution.docs.id
}

# --- GitHub Actions OIDC ---

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions -- use this in workflow files with aws-actions/configure-aws-credentials"
  value       = aws_iam_role.github_actions_cicd.arn
}

output "github_actions_oidc_provider_arn" {
  description = "OIDC provider ARN -- only one per AWS account per issuer URL"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}
