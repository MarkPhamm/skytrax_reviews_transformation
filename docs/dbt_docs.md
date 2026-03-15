# dbt Docs Hosting

## Live URL

**<https://d38l3fc9bckvbz.cloudfront.net>**

Docs are automatically updated on every merge to `main` — the CD pipeline runs `dbt docs generate`, uploads to S3, and invalidates the CloudFront cache.

## How It Works

```text
merge to main
  → GitHub Actions: dbt docs generate
  → aws s3 sync docs/ to s3://bucket/docs/
  → aws cloudfront create-invalidation (bust cache)
  → CloudFront serves latest docs from S3
```

- **S3** stores the static files (`index.html`, `manifest.json`, `catalog.json`)
- **CloudFront** serves them over HTTPS via a global CDN
- **Origin Access Control (OAC)** lets CloudFront read from S3 without making the bucket public
- Cache TTL is 5 minutes — after invalidation, the latest docs are live immediately

## Why CloudFront + S3 Instead of EC2

We originally planned an EC2 + nginx approach (the Terraform code is still in `ec2.tf.disabled` and `vpc.tf.disabled` for reference). Here's why we switched:

| | EC2 + nginx | CloudFront + S3 |
| - | --- | --- |
| **Cost** | ~$8/month after free tier expires | $0 (permanent free tier: 1TB/month) |
| **Maintenance** | OS patches, nginx config, cron job to sync from S3 | Zero — fully managed |
| **Update speed** | 5-minute cron delay | Instant (cache invalidation) |
| **HTTPS** | Requires ACM cert + ALB or certbot | Built-in with `*.cloudfront.net` |
| **Availability** | Single AZ, single instance | Global edge network, 99.9% SLA |
| **Infrastructure** | VPC, subnet, IGW, route table, security group, IAM role, instance profile | 3 resources (distribution, OAC, bucket policy) |

The EC2 approach is more educational (you learn VPC networking, security groups, user data scripts, cron), but for a static site like dbt docs, CloudFront is the right tool.

## Terraform Resources

All defined in `terraform/aws/cloudfront.tf`:

- `aws_cloudfront_origin_access_control.docs` — lets CloudFront authenticate to S3
- `aws_cloudfront_distribution.docs` — the CDN distribution, points to `s3://bucket/docs/`
- `aws_s3_bucket_policy.cloudfront_access` — grants CloudFront read access to the bucket

The GitHub Actions IAM role also has `cloudfront:CreateInvalidation` permission so the CD pipeline can bust the cache.

## GitHub Secrets

| Secret | Value |
| -------- | ------- |
| `CLOUDFRONT_DISTRIBUTION_ID` | `E3LT0BDSMSIG7H` |

This is used in the deploy workflow to invalidate the cache after uploading docs.
