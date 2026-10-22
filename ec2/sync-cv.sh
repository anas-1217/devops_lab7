#!/bin/bash
set -u
BUCKET="cv-23l-3005"
PREFIX="site/"
WEBROOT="/usr/share/nginx/html"
LOG="/var/log/cv-sync.log"
now() { date --iso-8601=seconds; }
status="failed"
# Get instance ID from IMDSv2; never use IMDSv1.
TOKEN="$(curl -fsS -X PUT 'http://169.254.169.254/latest/api/token' \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' 2>/dev/null)" || TOKEN=""
INSTANCE_ID=""
if [ -n "$TOKEN" ]; then
  INSTANCE_ID="$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)" || INSTANCE_ID=""
fi
if [ -n "$INSTANCE_ID" ] && aws s3 sync "s3://${BUCKET}/${PREFIX}" "$WEBROOT/" --only-show-errors; then
  if grep -q '{{HOSTED_ON}}' "$WEBROOT/index.html"; then
    sed -i "s/{{HOSTED_ON}}/EC2 — ${INSTANCE_ID}/g" "$WEBROOT/index.html"
  fi
  chown -R nginx:nginx "$WEBROOT"
  status="success"
fi
printf '%s sync=%s instance_id=%s\n' "$(now)" "$status" "${INSTANCE_ID:-unknown}" >> "$LOG"
[ "$status" = "success" ]
