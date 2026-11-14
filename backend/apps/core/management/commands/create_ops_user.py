"""Create/refresh the operations superuser from env or CLI options.

    python manage.py create_ops_user --email ops@zuum.in --password '...'
    # or DJANGO_SUPERUSER_EMAIL / DJANGO_SUPERUSER_PASSWORD in the environment
"""
from __future__ import annotations

import os

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand, CommandError

User = get_user_model()


class Command(BaseCommand):
    help = "Create or update the ops (staff) superuser."

    def add_arguments(self, parser):
        parser.add_argument("--email", default=os.getenv("DJANGO_SUPERUSER_EMAIL"))
        parser.add_argument("--password", default=os.getenv("DJANGO_SUPERUSER_PASSWORD"))
        parser.add_argument("--first-name", default="Ops")
        parser.add_argument("--last-name", default="Desk")

    def handle(self, *args, **options):
        email = (options.get("email") or "").strip().lower()
        password = options.get("password") or ""
        if not email or not password:
            # Free Render services run this on boot with no shell; a missing
            # env must not take the whole service down.
            self.stdout.write(
                self.style.WARNING(
                    "Skipping ops superuser: set DJANGO_SUPERUSER_EMAIL and "
                    "DJANGO_SUPERUSER_PASSWORD (or pass --email/--password)."
                )
            )
            return
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "first_name": options.get("first_name") or "Ops",
                "last_name": options.get("last_name") or "Desk",
                "role": User.Role.STAFF,
            },
        )
        user.role = User.Role.STAFF
        user.is_staff = True
        user.is_superuser = True
        user.is_active = True
        user.first_name = options.get("first_name") or user.first_name or "Ops"
        user.last_name = options.get("last_name") or user.last_name or "Desk"
        user.set_password(password)
        user.save()
        action = "Created" if created else "Updated"
        self.stdout.write(self.style.SUCCESS(f"{action} ops superuser {email}"))
