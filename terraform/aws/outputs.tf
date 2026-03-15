# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------
# These values are needed to configure CI/CD pipelines and access the docs.
# -----------------------------------------------------------------------------

output "artifacts_bucket_name" {
  description = "S3 bucket name for dbt artifacts"
  value       = aws_s3_bucket.dbt_artifacts.id
}

output "artifacts_bucket_arn" {
  description = "S3 bucket ARN for dbt artifacts (use in CI/CD IAM policies)"
  value       = aws_s3_bucket.dbt_artifacts.arn
}

output "docs_server_public_ip" {
  description = "Public IP of the dbt docs server -- visit http://<this-ip> to view docs"
  value       = aws_instance.docs_server.public_ip
}

output "docs_server_public_dns" {
  description = "Public DNS of the dbt docs server"
  value       = aws_instance.docs_server.public_dns
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}
