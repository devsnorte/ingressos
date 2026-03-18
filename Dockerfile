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
