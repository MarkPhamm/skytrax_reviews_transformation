# EC2 IAM resources removed -- see ec2.tf.disabled

# =============================================================================
# GitHub Actions OIDC -- Keyless CI/CD Authentication
# =============================================================================
# Instead of storing long-lived AWS access keys in GitHub Secrets, we use
# OpenID Connect (OIDC) so GitHub Actions can assume an IAM role directly.
# This is more secure: no static credentials to rotate or leak.
#
# How it works:
#   1. GitHub Actions requests a short-lived OIDC token from its own provider
#   2. The workflow calls aws-actions/configure-aws-credentials with this role ARN
#   3. AWS STS validates the token against the OIDC provider below
#   4. If the token's "sub" claim matches our repo, STS issues temporary creds
# =============================================================================

# --- OIDC Identity Provider ---
# Register GitHub's OIDC issuer with AWS so STS can validate tokens.
# The thumbprint is GitHub's TLS certificate fingerprint. AWS uses it to verify
# the OIDC endpoint's identity. This value is stable and documented by GitHub.

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  # The "aud" (audience) claim that GitHub tokens will contain
  client_id_list = ["sts.amazonaws.com"]

  # GitHub Actions OIDC thumbprint -- see:
  # https://github.blog/changelog/2023-06-27-github-actions-update-on-oidc-integration-with-aws/
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name = "${var.project_name}-github-oidc"
  }
}

# --- IAM Role for GitHub Actions ---
# The trust policy scopes access to a specific GitHub repo. The "sub" claim
# encodes the repo, branch, and event type, so we can control exactly which
# workflows are allowed to assume this role.

resource "aws_iam_role" "github_actions_cicd" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Allow both push-to-main and pull request events from this repo.
            # The wildcard after "ref:refs/" covers:
            #   - "ref:refs/heads/main" (deploy_main.yml on push)
            #   - "ref:refs/pull/*/merge" (pr_checks.yml on PRs)
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-github-actions-role"
  }
}

# --- S3 Policy for CI/CD ---
# Grants read/write access to the dbt artifacts bucket. This covers:
#   - deploy_main.yml: `aws s3 sync --delete` to upload artifacts and docs
#   - pr_checks.yml:   reading production state for slim CI comparison

resource "aws_iam_role_policy" "github_actions_s3" {
  name = "${var.project_name}-github-actions-s3"
  role = aws_iam_role.github_actions_cicd.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.dbt_artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.dbt_artifacts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Resource = aws_cloudfront_distribution.docs.arn
      }
    ]
  })
}
