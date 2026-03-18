#!/bin/bash
set -e

echo "==> Generating pretix config..."
/scripts/generate-config.sh

echo "==> Running database migrations..."
cd /pretix/src
python -m pretix migrate --noinput

echo "==> Rebuilding static files..."
python -m pretix rebuild

echo "==> Starting supervisord..."
exec supervisord -n -c /etc/supervisord.conf
