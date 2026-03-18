# Ingressos Fly.io Deployment — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Deploy a pretix fork as "ingressos" to Fly.io under the devsnorte org, running in São Paulo region.

**Architecture:** Single Fly machine running gunicorn + celery via supervisord. Fly Postgres for the database, Upstash Redis for cache/broker, Fly Volume for media storage. Pretix reads config from `/etc/pretix/pretix.cfg` — we generate this file at startup from Fly secrets/env vars.

**Tech Stack:** Python 3.11, Django 4.2, Celery, PostgreSQL, Redis, supervisord, Fly.io

---

### Task 1: Clone pretix into the project

**Files:**
- Directory: `pretix/` (git clone)

**Step 1: Clone the pretix repo**

```bash
cd /Users/iagocavalcante/Workspaces/DevsNorte/ingressos
git clone https://github.com/pretix/pretix.git pretix
```

**Step 2: Verify the clone**

```bash
ls pretix/src/pretix/settings.py
```
Expected: file exists

**Step 3: Initialize git for the ingressos project**

```bash
cd /Users/iagocavalcante/Workspaces/DevsNorte/ingressos
git init
```

**Step 4: Create .gitignore**

Create `.gitignore`:
```
.env
*.pyc
__pycache__
data/
```

**Step 5: Commit**

```bash
git add .gitignore pretix docs/
git commit -m "feat: init ingressos project with pretix clone and deployment design"
```

---

### Task 2: Create the pretix config generator script

Pretix reads config from `/etc/pretix/pretix.cfg` (INI format). On Fly, we pass secrets as env vars. This script converts env vars to the config file at container startup.

**Files:**
- Create: `scripts/generate-config.sh`

**Step 1: Write the config generator**

Create `scripts/generate-config.sh`:
```bash
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
```

**Step 2: Make it executable**

```bash
chmod +x scripts/generate-config.sh
```

**Step 3: Commit**

```bash
git add scripts/generate-config.sh
git commit -m "feat: add pretix config generator from env vars"
```

---

### Task 3: Create the entrypoint script

**Files:**
- Create: `scripts/start.sh`

**Step 1: Write the entrypoint**

Create `scripts/start.sh`:
```bash
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
```

**Step 2: Make it executable**

```bash
chmod +x scripts/start.sh
```

**Step 3: Commit**

```bash
git add scripts/start.sh
git commit -m "feat: add entrypoint script with migrations and supervisord"
```

---

### Task 4: Create supervisord config

**Files:**
- Create: `supervisord.conf`

**Step 1: Write supervisord.conf**

Create `supervisord.conf`:
```ini
[supervisord]
nodaemon=true
logfile=/data/logs/supervisord.log
pidfile=/tmp/supervisord.pid
user=pretixuser

[program:gunicorn]
command=/usr/local/bin/gunicorn pretix.wsgi --name pretix --workers 2 --max-requests 1200 --max-requests-jitter 50 --log-level info --bind 0.0.0.0:8000
directory=/pretix/src
user=pretixuser
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:celery]
command=/usr/local/bin/celery -A pretix.celery_app worker -l info --concurrency 2 -Q celery,default,checkout,mail,background,notifications
directory=/pretix/src
user=pretixuser
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
```

**Step 2: Commit**

```bash
git add supervisord.conf
git commit -m "feat: add supervisord config for gunicorn + celery"
```

---

### Task 5: Create the Dockerfile

**Files:**
- Create: `Dockerfile`

**Step 1: Write the Dockerfile**

Create `Dockerfile`:
```dockerfile
FROM python:3.11-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    LC_ALL=C.UTF-8 \
    DJANGO_SETTINGS_MODULE=production_settings

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gettext \
    git \
    libffi-dev \
    libjpeg-dev \
    libmemcached-dev \
    libpq-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    locales \
    nginx \
    nodejs \
    npm \
    python3-virtualenv \
    supervisor \
    sudo \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash pretixuser

# Copy pretix source
COPY pretix /pretix

# Install pretix
WORKDIR /pretix
RUN pip install --upgrade pip setuptools wheel && \
    pip install -e ".[postgres]" && \
    pip install gunicorn redis supervisor

# Copy production settings alongside pretix
COPY production_settings.py /pretix/src/production_settings.py

# Copy deployment files
COPY scripts/ /scripts/
COPY supervisord.conf /etc/supervisord.conf

RUN chmod +x /scripts/*.sh

# Create data directories
RUN mkdir -p /data/media /data/logs /etc/pretix && \
    chown -R pretixuser:pretixuser /data /etc/pretix /pretix

EXPOSE 8000

CMD ["/scripts/start.sh"]
```

**Step 2: Commit**

```bash
git add Dockerfile
git commit -m "feat: add Dockerfile for Fly.io deployment"
```

---

### Task 6: Create production settings

**Files:**
- Create: `production_settings.py`

**Step 1: Write production_settings.py**

Create `production_settings.py`:
```python
from pretix.settings import *  # noqa

STATIC_ROOT = "/pretix/src/static.dist"
STATICFILES_STORAGE = "django.contrib.staticfiles.storage.ManifestStaticFilesStorage"

LOGGING["handlers"]["mail_admins"]["class"] = "logging.NullHandler"  # noqa
```

**Step 2: Commit**

```bash
git add production_settings.py
git commit -m "feat: add production Django settings"
```

---

### Task 7: Create fly.toml

**Files:**
- Create: `fly.toml`

**Step 1: Write fly.toml**

Create `fly.toml`:
```toml
app = "ingressos"
primary_region = "gru"

[build]

[http_service]
  internal_port = 8000
  force_https = true
  auto_stop_machines = "stop"
  auto_start_machines = true
  min_machines_running = 0

[[vm]]
  size = "shared-cpu-2x"
  memory = "1gb"

[mounts]
  source = "ingressos_data"
  destination = "/data"

[checks]
  [checks.health]
    type = "http"
    port = 8000
    path = "/healthcheck/"
    interval = "30s"
    timeout = "5s"
```

**Step 2: Commit**

```bash
git add fly.toml
git commit -m "feat: add fly.toml configuration"
```

---

### Task 8: Create .env.example and .dockerignore

**Files:**
- Create: `.env.example`
- Create: `.dockerignore`

**Step 1: Write .env.example**

Create `.env.example`:
```bash
SECRET_KEY=change-me-to-a-random-string
PRETIX_URL=https://ingressos.fly.dev
DB_NAME=ingressos
DB_USER=postgres
DB_PASSWORD=
DB_HOST=
DB_PORT=5432
REDIS_URL=redis://default:password@host:6379
```

**Step 2: Write .dockerignore**

Create `.dockerignore`:
```
.git
.env
*.pyc
__pycache__
docs/
pretix/.git
pretix/.github
```

**Step 3: Commit**

```bash
git add .env.example .dockerignore
git commit -m "feat: add env example and dockerignore"
```

---

### Task 9: Create Fly app and infrastructure

**Step 1: Create the Fly app**

```bash
fly apps create ingressos --org devsnorte
```

**Step 2: Create Fly Postgres**

```bash
fly postgres create --name ingressos-db --org devsnorte --region gru --vm-size shared-cpu-1x --initial-cluster-size 1 --volume-size 1
```

**Step 3: Attach Postgres to the app**

```bash
fly postgres attach ingressos-db --app ingressos
```
This sets `DATABASE_URL` automatically. Note the connection details printed.

**Step 4: Create Fly Redis (Upstash)**

```bash
fly redis create --name ingressos-redis --org devsnorte --region gru --no-eviction
```
Note the Redis URL printed.

**Step 5: Create the volume for media data**

```bash
fly volumes create ingressos_data --app ingressos --region gru --size 1
```

---

### Task 10: Set secrets and deploy

**Step 1: Set secrets**

Use the DB credentials from Task 9 Step 3 and Redis URL from Step 4:

```bash
fly secrets set \
  SECRET_KEY="$(openssl rand -hex 32)" \
  DB_HOST="ingressos-db.flycast" \
  DB_PASSWORD="<password-from-step-3>" \
  DB_NAME="ingressos" \
  DB_USER="postgres" \
  REDIS_URL="<redis-url-from-step-4>" \
  PRETIX_URL="https://ingressos.fly.dev" \
  --app ingressos
```

**Step 2: Deploy**

```bash
fly deploy --app ingressos
```

**Step 3: Verify the app is running**

```bash
fly status --app ingressos
fly logs --app ingressos
```

**Step 4: Create admin user**

```bash
fly ssh console --app ingressos -C "cd /pretix/src && python -m pretix createsuperuser"
```

**Step 5: Open the app**

```bash
fly open --app ingressos
```

Expected: pretix login page at https://ingressos.fly.dev

**Step 6: Commit final state**

```bash
git add -A
git commit -m "docs: finalize deployment plan"
```

---

## Summary

| Task | Description | ~Time |
|------|-------------|-------|
| 1 | Clone pretix | 2 min |
| 2 | Config generator script | 3 min |
| 3 | Entrypoint script | 2 min |
| 4 | Supervisord config | 2 min |
| 5 | Dockerfile | 3 min |
| 6 | Production settings | 2 min |
| 7 | fly.toml | 2 min |
| 8 | .env.example + .dockerignore | 2 min |
| 9 | Create Fly infra (app, db, redis, volume) | 5 min |
| 10 | Set secrets + deploy + verify | 10 min |
