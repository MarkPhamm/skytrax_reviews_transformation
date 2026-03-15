# =============================================================================
# AWS Infrastructure for Skytrax Reviews dbt Project
# =============================================================================
# This file creates:
#   1. S3 bucket for dbt artifacts (slim CI state comparison)
#   2. VPC with a public subnet for the dbt docs server
#   3. EC2 instance running nginx to serve dbt docs
# =============================================================================

# Look up the latest Amazon Linux 2023 AMI so we don't hardcode AMI IDs
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get the current AWS account ID and region (avoids hardcoding)
data "aws_caller_identity" "current" {}

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

# =============================================================================
# VPC & Networking
# =============================================================================
# A simple VPC with one public subnet. This is intentionally minimal for a
# learning project. Production setups would use private subnets + a load balancer.

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Security Group -- dbt Docs Server
# =============================================================================
# Allow HTTP (for the docs site) and SSH (for administration).
# SSH is restricted to the CIDR you specify in allowed_ssh_cidr.

resource "aws_security_group" "docs_server" {
  name_prefix = "${var.project_name}-docs-"
  description = "Allow HTTP and SSH access to the dbt docs server"
  vpc_id      = aws_vpc.main.id

  # HTTP -- open to the world so anyone can view docs
  ingress {
    description = "HTTP for dbt docs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH -- restricted to your IP (override allowed_ssh_cidr)
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Allow all outbound (needed for yum updates, S3 sync, etc.)
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-docs-sg"
  }
}

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

# =============================================================================
# EC2 Instance -- dbt Docs Server
# =============================================================================
# A small instance that runs nginx to serve the dbt docs static site.
# A cron job syncs docs from S3 every 5 minutes.

resource "aws_instance" "docs_server" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.docs_server.id]
  key_name               = var.ssh_key_name
  iam_instance_profile   = aws_iam_instance_profile.docs_server.name

  # Run the setup script on first boot
  user_data = templatefile("${path.module}/user_data.sh", {
    s3_bucket = aws_s3_bucket.dbt_artifacts.id
  })

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-docs-server"
  }
}
