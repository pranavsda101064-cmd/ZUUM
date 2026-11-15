"""Seed the production demo accounts (catalog + ops + approved partner + customer).

    SEED_PASSWORD='choose-a-strong-password' python manage.py seed_production_demo

- With SEED_PASSWORD: accounts are created/updated to that password (stable).
- Without it: a random password is generated only for NEW accounts; existing
  passwords are left untouched so free-tier restarts never rotate them.
Safe to re-run.
"""
from __future__ import annotations

import os
import secrets
from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import (
    CustomerProfile,
    DriverProfile,
    KycDocument,
    User,
    Vehicle,
)
from apps.core.seed import seed_catalog
from apps.payments.models import Wallet


class Command(BaseCommand):
    help = "Seed the catalog plus ops, approved partner and customer accounts."

    def handle(self, *args, **options):
        categories = seed_catalog()

        password_env = os.getenv("SEED_PASSWORD")
        password = password_env or secrets.token_urlsafe(10)
        ops_email = os.getenv("SEED_OPS_EMAIL", "ops@zuum.in")
        partner_email = os.getenv("SEED_PARTNER_EMAIL", "partner@zuum.in")
        customer_email = os.getenv("SEED_CUSTOMER_EMAIL", "customer@zuum.in")

        ops, ops_created = User.objects.get_or_create(
            email=ops_email,
            defaults={"first_name": "Ops", "last_name": "Desk", "role": User.Role.STAFF},
        )
        ops.role = User.Role.STAFF
        ops.is_staff = True
        ops.is_superuser = True
        ops.is_active = True
        if ops_created or password_env:
            ops.set_password(password)
        ops.save()

        partner_user, partner_created = User.objects.get_or_create(
            email=partner_email,
            defaults={
                "first_name": "Ravi",
                "last_name": "Kumar",
                "phone": "9845012345",
                "role": User.Role.DRIVER,
            },
        )
        partner_user.role = User.Role.DRIVER
        partner_user.is_active = True
        if partner_created or password_env:
            partner_user.set_password(password)
        partner_user.save()

        partner, _ = DriverProfile.objects.get_or_create(
            user=partner_user,
            defaults={"languages": ["Kannada", "English"]},
        )
        partner.licence_number = partner.licence_number or "KA0120180012345"
        partner.kyc_status = DriverProfile.KYC_APPROVED
        partner.approval_status = DriverProfile.APPROVAL_ACTIVE
        partner.submitted_at = partner.submitted_at or timezone.now()
        partner.reviewed_at = timezone.now()
        partner.rating_avg = partner.rating_avg or Decimal("4.80")
        partner.rating_count = partner.rating_count or 126
        partner.online_state = DriverProfile.ONLINE_OFFLINE
        partner.home_lat = partner.home_lat or 12.9352
        partner.home_lng = partner.home_lng or 77.6245
        partner.languages = partner.languages or ["Kannada", "English"]
        partner.save()
        expiry = (timezone.now() + timedelta(days=365)).date()
        for doc_type in (
            KycDocument.Type.LICENCE,
            KycDocument.Type.RC,
            KycDocument.Type.INSURANCE,
        ):
            KycDocument.objects.update_or_create(
                driver=partner,
                type=doc_type,
                defaults={
                    "status": KycDocument.Status.VERIFIED,
                    "expires_at": expiry,
                },
            )
        Vehicle.objects.update_or_create(
            registration_number="KA05AB1234",
            defaults={
                "driver": partner,
                "category": categories["auto"],
                "make": "Bajaj",
                "model": "RE Auto",
                "color": "Yellow",
                "is_active": True,
            },
        )

        customer, customer_created = User.objects.get_or_create(
            email=customer_email,
            defaults={
                "first_name": "Aarav",
                "last_name": "Menon",
                "phone": "9845011111",
                "role": User.Role.CUSTOMER,
            },
        )
        customer.role = User.Role.CUSTOMER
        customer.is_active = True
        if customer_created or password_env:
            customer.set_password(password)
        customer.save()
        CustomerProfile.objects.get_or_create(user=customer)
        Wallet.objects.get_or_create(customer=customer)

        self.stdout.write(self.style.SUCCESS("Production demo data seeded."))
        if password_env or (ops_created and partner_created and customer_created):
            self.stdout.write("  Save these credentials now (shown once):")
            self.stdout.write(f"    ops      {ops_email} / {password}")
            self.stdout.write(f"    partner  {partner_email} / {password}")
            self.stdout.write(f"    customer {customer_email} / {password}")
        else:
            self.stdout.write(
                "  Accounts already existed; passwords were NOT changed."
            )
            self.stdout.write(
                f"  {ops_email} · {partner_email} · {customer_email}"
            )
            self.stdout.write(
                self.style.WARNING(
                    "  Set SEED_PASSWORD to rotate all three passwords on next boot."
                )
            )
