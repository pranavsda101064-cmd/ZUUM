FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
# Compile static assets with production settings (whitenoise).
RUN DEBUG=0 python manage.py collectstatic --noinput || true

EXPOSE 8000

# Render provides $PORT; daphne serves HTTP + WebSockets behind the proxy.
CMD ["sh", "-c", "daphne -b 0.0.0.0 -p ${PORT:-8000} --proxy-headers config.asgi:application"]
