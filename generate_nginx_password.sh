#! /bin/bash

set -euxo pipefail

username=$1

password_line=$username:`openssl passwd -apr1`

echo "$password_line" >> /usr/share/nginx/htpasswd

chown nginx:nginx /usr/share/nginx/htpasswd
chmod 0600 /usr/share/nginx/htpasswd
