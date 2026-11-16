FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

# NOTE: Render builds with the repository root as the Docker context (even when
# this Dockerfile lives in backend/). All COPY paths are therefore repo-relative.
# Local: docker build -f backend/Dockerfile -t zuum .
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .
# Compile static assets with production settings (whitenoise).
RUN SECRET_KEY=build-only ALLOWED_HOSTS=localhost DEBUG=0 \
    python manage.py collectstatic --noinput
RUN chmod +x /app/start.sh

EXPOSE 8000

# Entrypoint runs migrations (+ optional demo seed when AUTO_SEED=1) then daphne.
CMD ["sh", "/app/start.sh"]
