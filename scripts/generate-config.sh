#!/bin/bash
set -e

mkdir -p /etc/pretix /data/media /data/logs

cat > /etc/pretix/pretix.cfg <<CONF
[pretix]
instance_name=Ingressos
url=${PRETIX_URL:-https://ingressos.fly.dev}
currency=BRL
datadir=/data
trust_x_forwarded_for=on
trust_x_forwarded_proto=on

[database]
backend=postgresql
name=${DB_NAME:-ingressos}
user=${DB_USER:-postgres}
password=${DB_PASSWORD}
host=${DB_HOST}
port=${DB_PORT:-5432}

[redis]
location=${REDIS_URL}
sessions=true

[celery]
broker=${REDIS_URL}
backend=${REDIS_URL}

[mail]
from=noreply@ingressos.fly.dev

[django]
secret=${SECRET_KEY}
debug=false
CONF

chown -R pretixuser:pretixuser /etc/pretix /data
chmod 0600 /etc/pretix/pretix.cfg
