#!/bin/bash
set -euxo pipefail
BUCKET="cv-23l-3005"
dnf install -y nginx awscli curl
systemctl enable --now nginx
install -d -o nginx -g nginx /usr/share/nginx/html

cat >/etc/nginx/conf.d/cv.conf <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /usr/share/nginx/html;
    index index.html;
    include /etc/nginx/mime.types;
    types { text/html html; text/css css; application/pdf pdf; }
    location / { try_files $uri $uri/ =404; }
}
EOF
rm -f /etc/nginx/conf.d/default.conf
nginx -t
systemctl reload nginx

cat >/usr/local/bin/cv-sync.sh <<'SYNC_SCRIPT'
#!/bin/bash
set -u
BUCKET="cv-23l-3005"
PREFIX="site/"
WEBROOT="/usr/share/nginx/html"
LOG="/var/log/cv-sync.log"
now() { date --iso-8601=seconds; }
status="failed"
TOKEN="$(curl -fsS -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' 2>/dev/null)" || TOKEN=""
INSTANCE_ID=""
if [ -n "$TOKEN" ]; then
  INSTANCE_ID="$(curl -fsS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)" || INSTANCE_ID=""
fi
if [ -n "$INSTANCE_ID" ] && aws s3 sync "s3://${BUCKET}/${PREFIX}" "$WEBROOT/" --only-show-errors; then
  sed -i "s/{{HOSTED_ON}}/EC2 — ${INSTANCE_ID}/g" "$WEBROOT/index.html"
  chown -R nginx:nginx "$WEBROOT"
  status="success"
fi
printf '%s sync=%s instance_id=%s\n' "$(now)" "$status" "${INSTANCE_ID:-unknown}" >> "$LOG"
[ "$status" = "success" ]
SYNC_SCRIPT
sed -i "s/cv-23l-3005/${BUCKET}/g" /usr/local/bin/cv-sync.sh
chmod 0755 /usr/local/bin/cv-sync.sh
/usr/local/bin/cv-sync.sh || true

cat >/etc/systemd/system/cv-sync.service <<'EOF'
[Unit]
Description=Sync CV website from private S3 bucket
[Service]
Type=oneshot
ExecStart=/usr/local/bin/cv-sync.sh
EOF
cat >/etc/systemd/system/cv-sync.timer <<'EOF'
[Unit]
Description=Run CV S3 sync every five minutes
[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=cv-sync.service
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now cv-sync.timer
