#!/bin/sh
if [ -z "$FQDN" ];then
	FQDN=localhost
fi

mkdir -p /etc/nginx/conf.d/includes

if [ ! -f "/etc/nginx/conf.d/includes/ssl.include" ];then
cat <<EOF >/etc/nginx/conf.d/includes/ssl.include
# This file contains important security parameters. If you modify this file
# manually, Certbot will be unable to automatically provide future security
# updates. Instead, Certbot will print and log an error message with a path to
# the up-to-date file that you will need to refer to when manually updating
# this file.

ssl_session_cache shared:le_nginx_SSL:10m;
ssl_session_timeout 1440m;
ssl_session_tickets off;

ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers off;

ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";
EOF
fi

if [ ! -f "/etc/nginx/conf.d/default.conf" ];then
cat <<EOF >/etc/nginx/conf.d/default.conf
upstream gwsocket {
    server 127.0.0.1:7890;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80 default_server;
    server_name _;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen       443 ssl http2;
    server_name  ${FQDN};

    ssl_certificate /etc/letsencrypt/live/${FQDN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${FQDN}/privkey.pem;
    include conf.d/includes/ssl.include;

    location / {
        alias /static_files/goaccess/;
        index report.html;
    }

    location /ws {
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_pass http://127.0.0.1:7890;
        proxy_buffering off;
        proxy_read_timeout 7d;
    }

}
EOF
fi

#Run goaccess & exec nginx afterwards
mkdir -p static_files/goaccess && touch /tmp/access.log
goaccess /tmp/access.log -o /static_files/goaccess/report.html --log-format=COMBINED --ws-url=wss://${FQDN}:443/ws --real-time-html &\
exec nginx "${@}"
