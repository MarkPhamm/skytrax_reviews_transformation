# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
# AWS provider authenticates via the standard credential chain:
# environment variables, shared credentials file, or IAM role.
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform-admin"

  default_tags {
    tags = {
      Project     = "skytrax-reviews"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
