#!/usr/bin/env bash
set -euxo pipefail

yum update -y
yum install -y nginx

INSTANCE_ID="unknown"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
if [[ -n "${TOKEN}" ]]; then
  INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" \
    http://169.254.169.254/latest/meta-data/instance-id || echo "unknown")
fi

cat > /usr/share/nginx/html/index.html <<HTML
<h1>Cloud Computing and AWS</h1>
<p>Server: ${INSTANCE_ID}</p>
HTML

systemctl enable nginx
systemctl restart nginx
