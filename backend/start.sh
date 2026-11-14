#!/bin/sh
# Render/free-plan boot: migrate, optionally seed demo data, then serve ASGI.
set -e

python manage.py migrate --noinput

if [ "${AUTO_SEED:-0}" = "1" ]; then
  # Both commands are idempotent; never let seeding take the API down.
  python manage.py create_ops_user || true
  python manage.py seed_production_demo || true
fi

exec daphne -b 0.0.0.0 -p "${PORT:-8000}" --proxy-headers config.asgi:application
