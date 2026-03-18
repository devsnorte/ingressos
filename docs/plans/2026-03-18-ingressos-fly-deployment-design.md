# Ingressos — Pretix Fork for Devs Norte

## What

A rebranded fork of [pretix](https://github.com/pretix/pretix) (open-source ticketing platform) for events in Northern Brazil, deployed to Fly.io.

## Target

Devs Norte community and events in Northern Brazil.

## Architecture (MVP)

- **App:** Single Fly machine running gunicorn + celery worker via supervisord
- **Database:** Fly Postgres (single node, smallest tier)
- **Cache/Broker:** Fly Redis (Upstash)
- **Storage:** Fly Volume for media uploads
- **Region:** `gru` (São Paulo)
- **Org:** `devsnorte`

## Project Structure

```
ingressos/
├── pretix/                  # Fork of pretix/pretix
├── fly.toml                 # Fly.io app config
├── Dockerfile               # Custom Dockerfile for Fly
├── supervisord.conf         # Process manager (gunicorn + celery)
├── .env.example             # Env var template
└── scripts/
    └── start.sh             # Entrypoint: migrations + static + supervisord
```

## Deployment Steps

1. Clone pretix into `pretix/`
2. Write Dockerfile (Python 3.11, pretix deps, supervisord)
3. Write `fly.toml` (app config, health checks, volume mounts)
4. Write `start.sh` (migrations, collectstatic, supervisord)
5. Write `supervisord.conf` (gunicorn + celery processes)
6. `fly apps create ingressos --org devsnorte`
7. `fly postgres create --name ingressos-db --org devsnorte --region gru`
8. `fly redis create --name ingressos-redis --org devsnorte --region gru`
9. `fly volumes create ingressos_data --region gru --size 1`
10. Set secrets (SECRET_KEY, DATABASE_URL, REDIS_URL, ALLOWED_HOSTS)
11. `fly deploy`
12. Create admin user via `fly ssh console`

## Not In Scope (Future)

- Custom branding / Portuguese translations
- Custom domain + SSL
- Email sending (SMTP config)
- Separate celery workers
- CI/CD pipeline
