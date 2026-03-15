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

# --- EC2 ---

variable "instance_type" {
  description = "EC2 instance type for the dbt docs server"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Name of an existing EC2 key pair for SSH access to the docs server"
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH into the docs server (e.g., your IP: 1.2.3.4/32)"
  type        = string
  default     = "0.0.0.0/0" # Restrict this in production!
}

# --- GitHub Actions OIDC ---

variable "github_repository" {
  description = "GitHub repository in 'owner/repo' format, used to scope the OIDC trust policy"
  type        = string
}
