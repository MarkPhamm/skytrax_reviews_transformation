# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod) -- used in resource naming and tags"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used as a prefix for resource naming"
  type        = string
  default     = "skytrax-reviews"
}

# --- S3 ---

variable "artifacts_bucket_name" {
  description = "Name for the S3 bucket that stores dbt artifacts. Must be globally unique."
  type        = string
}

# EC2 variables removed -- see ec2.tf.disabled

# --- GitHub Actions OIDC ---

variable "github_repository" {
  description = "GitHub repository in 'owner/repo' format, used to scope the OIDC trust policy"
  type        = string
}
