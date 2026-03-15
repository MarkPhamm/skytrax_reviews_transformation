# =============================================================================
# EC2 Instance -- dbt Docs Server
# =============================================================================
# A small instance that runs nginx to serve the dbt docs static site.
# A cron job syncs docs from S3 every 5 minutes.

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

# Security group -- allow HTTP (docs) and SSH (admin)
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
