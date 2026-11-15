"""Django settings for the Zuum backend.

Dev defaults run on SQLite with the in-memory channel layer so the full API
and websocket surface works with zero services. Production pulls Postgres,
Redis and secrets from the environment (`infra/render.yaml`).
"""
from __future__ import annotations

import os
import urllib.parse
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

SECRET_KEY = (
    os.getenv("SECRET_KEY")
    or os.getenv("DJANGO_SECRET_KEY")
    or "dev-insecure-zuum-secret-change-me"
)
DEBUG = os.getenv("DEBUG", "1") == "1"
ALLOWED_HOSTS = [h.strip() for h in os.getenv("ALLOWED_HOSTS", "*").split(",") if h.strip()]

CSRF_TRUSTED_ORIGINS = [
    o.strip() for o in os.getenv("CSRF_TRUSTED_ORIGINS", "").split(",") if o.strip()
]
if not CSRF_TRUSTED_ORIGINS and not DEBUG:
    CSRF_TRUSTED_ORIGINS = ["https://*.onrender.com"]

# Render terminates TLS at the proxy; trust its headers.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True
SECURE_SSL_REDIRECT = os.getenv("SECURE_SSL_REDIRECT", "0") == "1"
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
SECURE_HSTS_SECONDS = int(os.getenv("SECURE_HSTS_SECONDS", "0"))

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # third-party
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "drf_spectacular",
    "corsheaders",
    "channels",
    # local
    "apps.core",
    "apps.accounts",
    "apps.catalog",
    "apps.bookings",
    "apps.payments",
    "apps.platform",
    "apps.api",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "apps.core.middleware.RequestIDMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASE_URL = os.getenv("DATABASE_URL", "")
if DATABASE_URL:
    parsed = urllib.parse.urlsplit(DATABASE_URL)
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": (parsed.path or "/zuum").lstrip("/"),
            "USER": parsed.username or "",
            "PASSWORD": parsed.password or "",
            "HOST": parsed.hostname or "",
            "PORT": str(parsed.port or 5432),
            "CONN_MAX_AGE": 600,
            "OPTIONS": {"sslmode": os.getenv("DB_SSL_MODE", "prefer")},
        }
    }
elif os.getenv("DB_ENGINE", "sqlite") == "postgres":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.getenv("DB_NAME", "zuum"),
            "USER": os.getenv("DB_USER", "zuum"),
            "PASSWORD": os.getenv("DB_PASSWORD", ""),
            "HOST": os.getenv("DB_HOST", "localhost"),
            "PORT": os.getenv("DB_PORT", "5432"),
            "CONN_MAX_AGE": 600,
            "OPTIONS": {"sslmode": os.getenv("DB_SSL_MODE", "prefer")},
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = []

LANGUAGE_CODE = "en-in"
TIME_ZONE = "Asia/Kolkata"
USE_I18N = True
USE_TZ = True

STATIC_URL = "/static/"
STATIC_ROOT = Path(os.getenv("STATIC_ROOT", BASE_DIR / "staticfiles"))
DATA_DIR = Path(os.getenv("DATA_DIR", BASE_DIR))
MEDIA_URL = "/media/"
MEDIA_ROOT = Path(os.getenv("MEDIA_ROOT", DATA_DIR / "media"))

STORAGES = {
    "default": {"BACKEND": "django.core.files.storage.FileSystemStorage"},
    "staticfiles": {
        "BACKEND": (
            "whitenoise.storage.CompressedStaticFilesStorage"
            if not DEBUG
            else "django.contrib.staticfiles.storage.StaticFilesStorage"
        )
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "EXCEPTION_HANDLER": "apps.core.exceptions.api_exception_handler",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "DEFAULT_FILTER_BACKENDS": ("django_filters.rest_framework.DjangoFilterBackend",),
    "DEFAULT_THROTTLE_RATES": {
        "auth": "10/min",
        "quote": "30/min",
        "bookings_write": "20/min",
    },
}

# Throttles are exercised explicitly; the test suite must not hit the
# production auth budget (10/min/IP) across hundreds of requests.
import sys as _sys

if "test" in _sys.argv:
    REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = {
        "auth": "10000/min",
        "quote": "10000/min",
        "bookings_write": "10000/min",
    }

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Zuum API",
    "DESCRIPTION": (
        "Mobility + logistics platform API. Consumer, partner and fleet "
        "surfaces under /api/v1/."
    ),
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "COMPONENT_SPLIT_REQUEST": True,
}

# --- Routing (Valhalla public demo in dev; env-swappable) --------------------
ROUTING_PROVIDER = os.getenv(
    "ROUTING_PROVIDER", "haversine" if _sys.argv[1:2] == ["test"] else "valhalla"
)
ROUTING_BASE_URL = os.getenv(
    "ROUTING_BASE_URL", "https://valhalla1.openstreetmap.de"
)
ROUTING_API_KEY = os.getenv("ROUTING_API_KEY", "")
ROUTING_TIMEOUT_MS = int(os.getenv("ROUTING_TIMEOUT_MS", "4500"))
ROUTING_CACHE_TTL = int(os.getenv("ROUTING_CACHE_TTL", "300"))
ROUTING_DEGRADED_TTL = int(os.getenv("ROUTING_DEGRADED_TTL", "30"))
ROUTING_CIRCUIT_SECONDS = int(os.getenv("ROUTING_CIRCUIT_SECONDS", "60"))
ROUTING_USER_AGENT = os.getenv(
    "ROUTING_USER_AGENT", "Zuum/1.0 (dev demo; OpenStreetMap + Valhalla)"
)
DISPATCH_USE_MATRIX = os.getenv("DISPATCH_USE_MATRIX", "0") == "1"
STALE_SEARCH_MINUTES = int(os.getenv("STALE_SEARCH_MINUTES", "5"))
EXPOSE_DEV_OTP = os.getenv("EXPOSE_DEV_OTP", "1" if DEBUG else "0") == "1"

# --- Places (OSM geocoding: Photon primary, Nominatim fallback) -------------
PLACES_PHOTON_URL = os.getenv("PLACES_PHOTON_URL", "https://photon.komoot.io")
PHOTON_URL = os.getenv("PHOTON_URL", PLACES_PHOTON_URL)
NOMINATIM_URL = os.getenv("NOMINATIM_URL", "https://nominatim.openstreetmap.org")
PLACES_TIMEOUT_MS = int(os.getenv("PLACES_TIMEOUT_MS", "4000"))
PLACES_CACHE_TTL = int(os.getenv("PLACES_CACHE_TTL", "600"))
PLACES_REVERSE_CACHE_TTL = int(os.getenv("PLACES_REVERSE_CACHE_TTL", "86400"))
PLACES_USER_AGENT = os.getenv(
    "PLACES_USER_AGENT", "Zuum/1.0 (dev demo; OpenStreetMap geocoding)"
)
# Bengaluru metro bias (min_lon,min_lat,max_lon,max_lat)
PLACES_BBOX = os.getenv("PLACES_BBOX", "77.35,12.75,77.85,13.20")


REDIS_URL = os.getenv("REDIS_URL", "")

CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "zuum-default",
    }
}
if REDIS_URL:
    CACHES["default"] = {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URL,
    }

if REDIS_URL:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {"hosts": [REDIS_URL]},
        }
    }
else:
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
    }

CELERY_BROKER_URL = os.getenv("CELERY_BROKER_URL", REDIS_URL or "memory://")
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", "cache+memory://")
CELERY_TASK_ALWAYS_EAGER = os.getenv("CELERY_EAGER", "1" if DEBUG else "0") == "1"
CELERY_TASK_EAGER_PROPAGATES = True

from celery.schedules import crontab  # noqa: E402

CELERY_BEAT_SCHEDULE = {
    "expire-dispatch-offers": {
        "task": "apps.bookings.tasks.expire_offers",
        "schedule": 15.0,
    },
    "fail-stale-searches": {
        "task": "apps.bookings.tasks.fail_stale_searches",
        "schedule": crontab(minute="*/5"),
    },
    "prune-location-pings": {
        "task": "apps.bookings.tasks.prune_location_pings",
        "schedule": crontab(hour=4, minute=0),
    },
    "weekly-payouts": {
        "task": "apps.payments.tasks.generate_weekly_payouts",
        "schedule": crontab(hour=2, minute=0, day_of_week=1),
    },
}

CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [
    o for o in os.getenv("CORS_ALLOWED_ORIGINS", "").split(",") if o
]

EMAIL_BACKEND = os.getenv(
    "EMAIL_BACKEND", "django.core.mail.backends.console.EmailBackend"
)
EMAIL_HOST = os.getenv("EMAIL_HOST", "")
if EMAIL_HOST and not os.getenv("EMAIL_BACKEND"):
    EMAIL_BACKEND = "django.core.mail.backends.smtp.EmailBackend"
EMAIL_PORT = int(os.getenv("EMAIL_PORT", "587"))
EMAIL_USE_TLS = os.getenv("EMAIL_USE_TLS", "1") == "1"
EMAIL_HOST_USER = os.getenv("EMAIL_HOST_USER", "")
EMAIL_HOST_PASSWORD = os.getenv("EMAIL_HOST_PASSWORD", "")
DEFAULT_FROM_EMAIL = os.getenv("DEFAULT_FROM_EMAIL", "no-reply@zuum.in")

# Rate limiting behind a single Render proxy (X-Forwarded-For aware).
NUM_PROXIES = int(os.getenv("NUM_PROXIES", "0" if DEBUG else "1"))

PASSWORD_RESET_SALT = "zuum.password.reset"
PASSWORD_RESET_TTL_SECONDS = 60 * 30

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
