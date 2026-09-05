#!/bin/bash
cat << 'EOF' > /etc/nginx/sites-available/rentilly
server {
    listen 80;
    server_name api.myrentilly.com;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/rentilly /etc/nginx/sites-enabled/rentilly
nginx -t
systemctl reload nginx
echo "NGINX_RELOADED_OK"
