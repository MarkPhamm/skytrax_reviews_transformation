#!/bin/bash
# =============================================================================
# EC2 User Data -- dbt Docs Server Setup
# =============================================================================
# This script runs once on first boot. It installs nginx, configures it to
# serve dbt docs, and sets up a cron job to sync docs from S3.
# =============================================================================

set -euo pipefail

# Update system packages
dnf update -y

# Install nginx and the AWS CLI (for S3 sync)
dnf install -y nginx aws-cli

# Create the directory where dbt docs will be served from
mkdir -p /var/www/dbt-docs

# Configure nginx to serve the dbt docs directory
cat > /etc/nginx/conf.d/dbt-docs.conf <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/dbt-docs;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
NGINX

# Remove the default nginx server block so ours takes effect
rm -f /etc/nginx/conf.d/default.conf

# Start nginx and enable it on boot
systemctl enable nginx
systemctl start nginx

# Create a script that syncs dbt docs from S3
cat > /usr/local/bin/sync-dbt-docs.sh <<'SYNC'
#!/bin/bash
# Sync dbt docs from S3 to the nginx serving directory
aws s3 sync s3://${s3_bucket}/docs/ /var/www/dbt-docs/ --delete --quiet
SYNC
chmod +x /usr/local/bin/sync-dbt-docs.sh

# Run the sync once immediately (docs may already be in S3)
/usr/local/bin/sync-dbt-docs.sh || true

# Set up a cron job to sync every 5 minutes
echo "*/5 * * * * root /usr/local/bin/sync-dbt-docs.sh" > /etc/cron.d/sync-dbt-docs
chmod 0644 /etc/cron.d/sync-dbt-docs
