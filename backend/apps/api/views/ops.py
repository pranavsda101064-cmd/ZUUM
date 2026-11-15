"""Ops/admin API — the surface the Flutter Web dashboard consumes.

Every endpoint requires `role=staff` (or superuser). Write actions are audited.
"""
from __future__ import annotations

import mimetypes
from datetime import timedelta

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDate
from django.http import FileResponse
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import DriverProfile, KycDocument, User, Vehicle
from apps.accounts.services import approve_driver
from apps.api.serializers import (
    BookingSerializer,
    DriverProfileSerializer,
    OpsKycDocumentSerializer,
    PayoutSerializer,
    PromoSerializer,
    UserSerializer,
    VehicleSerializer,
)
from apps.bookings.models import Booking, DispatchOffer, LocationPing
from apps.bookings.services import cancel_booking
from apps.catalog.models import PromoCampaign
from apps.core.audit import audit
from apps.core.exceptions import ApiError
from apps.core.notifications import notify_user
from apps.core.permissions import IsStaffUser
from apps.payments.models import CommissionEntry, Payout
from apps.platform.models import AuditLog, Notification, SosAlert, SupportMessage, SupportTicket


def _start_of_today():
    return timezone.localtime().replace(hour=0, minute=0, second=0, microsecond=0)


def _range_start(key: str):
    now = timezone.localtime()
    if key == "week":
        return now - timedelta(days=7)
    if key == "month":
        return now - timedelta(days=30)
    return _start_of_today()


def _paginate(request, qs, serialize):
    page = max(1, int(request.query_params.get("page", 1) or 1))
    size = max(1, min(100, int(request.query_params.get("page_size", 20) or 20)))
    total = qs.count()
    items = qs[(page - 1) * size : page * size]
    return {
        "count": total,
        "next": (
            request.build_absolute_uri(f"?page={page + 1}&page_size={size}")
            if page * size < total
            else None
        ),
        "previous": None,
        "results": serialize(items),
    }


class OpsOverviewView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = UserSerializer

    def get(self, request):
        today = _start_of_today()
        today_bookings = Booking.objects.filter(created_at__gte=today)
        by_status = {
            row["status"]: row["count"]
            for row in today_bookings.values("status").annotate(count=Count("id"))
        }
        completed = Booking.objects.filter(
            status=Booking.Status.COMPLETED, completed_at__gte=today
        )
        commission = CommissionEntry.objects.filter(created_at__gte=today).aggregate(
            total=Sum("platform_paise")
        )["total"] or 0
        online = DriverProfile.objects.exclude(
            online_state=DriverProfile.ONLINE_OFFLINE
        ).count()
        return Response(
            {
                "bookings_today": today_bookings.count(),
                "active_by_status": by_status,
                "online_drivers": online,
                "drivers_total": DriverProfile.objects.count(),
                "pending_kyc": DriverProfile.objects.filter(
                    kyc_status=DriverProfile.KYC_SUBMITTED
                ).count(),
                "completed_today": completed.count(),
                "revenue_today_paise": completed.aggregate(
                    total=Sum("final_fare_paise")
                )["total"]
                or 0,
                "commission_today_paise": commission,
                "open_tickets": SupportTicket.objects.filter(
                    status__in=[
                        SupportTicket.Status.OPEN,
                        SupportTicket.Status.PENDING,
                    ]
                ).count(),
                "active_sos": SosAlert.objects.filter(resolved_at__isnull=True).count(),
                "payouts_pending_paise": Payout.objects.filter(
                    status__in=[Payout.Status.PENDING, Payout.Status.PROCESSING]
                ).aggregate(total=Sum("amount_paise"))["total"]
                or 0,
                "generated_at": timezone.now(),
            }
        )


class OpsBookingListView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = BookingSerializer

    def get(self, request):
        qs = (
            Booking.objects.select_related("customer", "service_category")
            .prefetch_related("offers__driver__user")
            .order_by("-created_at")
        )
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"].upper())
        if request.query_params.get("type"):
            qs = qs.filter(type=request.query_params["type"])
        q = (request.query_params.get("q") or "").strip()
        if q:
            qs = qs.filter(
                Q(id__icontains=q)
                | Q(customer__email__icontains=q)
                | Q(customer__first_name__icontains=q)
                | Q(pickup_address__icontains=q)
                | Q(drop_address__icontains=q)
            )
        data = _paginate(
            request,
            qs,
            lambda items: [
                {
                    "id": str(b.id),
                    "type": b.type,
                    "status": b.status,
                    "service_category": b.service_category.name,
                    "customer": b.customer.email,
                    "driver": (
                        b.offers.filter(status="accepted")
                        .first()
                        .driver.user.full_name
                        if b.offers.filter(status="accepted").exists()
                        else None
                    ),
                    "pickup": b.pickup_address,
                    "drop": b.drop_address,
                    "distance_m": b.distance_m,
                    "fare_paise": b.final_fare_paise or b.quoted_fare_paise,
                    "payment_state": b.payment_state,
                    "created_at": b.created_at,
                }
                for b in items
            ],
        )
        return Response(data)


class OpsBookingDetailView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = BookingSerializer

    def get(self, request, booking_id):
        booking = (
            Booking.objects.filter(pk=booking_id)
            .select_related("customer", "service_category")
            .prefetch_related(
                "offers__driver__user", "offers__vehicle__category", "history"
            )
            .first()
        )
        if booking is None:
            raise ApiError("Booking not found", code="not_found", status_code=404)
        payload = BookingSerializer(booking).data
        payload["customer"] = UserSerializer(booking.customer).data
        payload["offers"] = [
            {
                "id": str(o.id),
                "driver": o.driver.user.full_name,
                "status": o.status,
                "fare_paise": o.booking.quoted_fare_paise,
                "offered_at": o.offered_at,
                "expires_at": o.expires_at,
            }
            for o in booking.offers.all()
        ]
        return Response(payload)


class OpsBookingCancelView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = BookingSerializer

    def post(self, request, booking_id):
        booking = Booking.objects.filter(pk=booking_id).first()
        if booking is None:
            raise ApiError("Booking not found", code="not_found", status_code=404)
        reason = (request.data.get("reason") or "Cancelled by operations").strip()
        cancel_booking(booking, by="system", actor_id=request.user.id, reason=reason)
        audit(
            actor=request.user,
            action="booking.cancel",
            entity=booking,
            after={"reason": reason},
        )
        return Response(BookingSerializer(booking).data)


class OpsDriverListView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = DriverProfileSerializer

    def get(self, request):
        qs = (
            DriverProfile.objects.select_related("user", "fleet")
            .prefetch_related("vehicles", "documents")
            .order_by("-created_at")
        )
        if request.query_params.get("kyc"):
            qs = qs.filter(kyc_status=request.query_params["kyc"])
        if request.query_params.get("approval"):
            qs = qs.filter(approval_status=request.query_params["approval"])
        q = (request.query_params.get("q") or "").strip()
        if q:
            qs = qs.filter(
                Q(user__email__icontains=q)
                | Q(user__first_name__icontains=q)
                | Q(user__phone__icontains=q)
                | Q(licence_number__icontains=q)
            )
        return Response(
            _paginate(
                request,
                qs,
                lambda items: [
                    {
                        "id": str(d.id),
                        "user": UserSerializer(d.user).data,
                        "kyc_status": d.kyc_status,
                        "approval_status": d.approval_status,
                        "fleet": d.fleet.name if d.fleet else None,
                        "online_state": d.online_state,
                        "rating_avg": float(d.rating_avg),
                        "rating_count": d.rating_count,
                        "document_count": d.documents.count(),
                        "vehicles": [
                            VehicleSerializer(v).data for v in d.vehicles.all()
                        ],
                        "documents": [
                            {
                                "type": doc.type,
                                "status": doc.status,
                                "expires_at": doc.expires_at,
                            }
                            for doc in d.documents.all()
                        ],
                        "created_at": d.created_at,
                    }
                    for d in items
                ],
            )
        )


class OpsDriverDetailView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = DriverProfileSerializer

    def get(self, request, driver_id):
        driver = (
            DriverProfile.objects.filter(pk=driver_id)
            .select_related("user", "fleet")
            .prefetch_related("vehicles__category", "documents")
            .first()
        )
        if driver is None:
            raise ApiError("Driver not found", code="not_found", status_code=404)
        driver_payload = DriverProfileSerializer(driver).data
        driver_payload["vehicles"] = [
            VehicleSerializer(v).data for v in driver.vehicles.all()
        ]
        return Response(
            {
                "driver": driver_payload,
                "documents": OpsKycDocumentSerializer(
                    driver.documents.order_by("created_at"), many=True
                ).data,
            }
        )


class OpsDocumentFileView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = OpsKycDocumentSerializer

    def get(self, request, document_id):
        document = KycDocument.objects.filter(pk=document_id).first()
        if document is None or not document.file:
            raise ApiError("Document file not found", code="not_found", status_code=404)
        content_type, _ = mimetypes.guess_type(document.file.name)
        return FileResponse(
            document.file.open("rb"),
            content_type=content_type or "application/octet-stream",
            as_attachment=False,
            filename=document.file.name.rsplit("/", 1)[-1],
        )


class OpsDocumentReviewView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = OpsKycDocumentSerializer

    def post(self, request, document_id):
        document = (
            KycDocument.objects.filter(pk=document_id)
            .select_related("driver__user")
            .first()
        )
        if document is None:
            raise ApiError("Document not found", code="not_found", status_code=404)
        review = (request.data.get("status") or "").strip().lower()
        note = (request.data.get("note") or "").strip()
        if review not in (KycDocument.Status.VERIFIED, KycDocument.Status.REJECTED):
            raise ApiError(
                "Status must be verified or rejected",
                code="validation_error",
                status_code=400,
            )
        if review == KycDocument.Status.REJECTED and not note:
            raise ApiError(
                "A rejection note is required",
                code="validation_error",
                status_code=400,
            )
        before = {"status": document.status, "review_note": document.review_note}
        document.status = review
        document.review_note = note[:240]
        document.reviewed_at = timezone.now()
        document.reviewed_by = request.user
        document.save(
            update_fields=[
                "status",
                "review_note",
                "reviewed_at",
                "reviewed_by",
                "updated_at",
            ]
        )
        driver = document.driver
        if review == KycDocument.Status.REJECTED:
            driver.kyc_status = DriverProfile.KYC_REJECTED
            driver.approval_status = DriverProfile.APPROVAL_PENDING
            driver.rejection_reason = f"{document.type}: {note}"[:240]
            driver.online_state = DriverProfile.ONLINE_OFFLINE
            driver.save(
                update_fields=[
                    "kyc_status",
                    "approval_status",
                    "rejection_reason",
                    "online_state",
                    "updated_at",
                ]
            )
            notify_user(
                driver.user,
                type="kyc",
                title="Document needs attention",
                body=f"{document.type.replace('_', ' ').title()}: {note}"[:500],
            )
        else:
            notify_user(
                driver.user,
                type="kyc",
                title="Document verified",
                body=f"{document.type.replace('_', ' ').title()} was verified by Zuum ops.",
            )
        audit(
            actor=request.user,
            action=f"document.{review}",
            entity=document,
            before=before,
            after={"status": document.status, "review_note": document.review_note},
        )
        return Response(OpsKycDocumentSerializer(document).data)


class OpsDriverDecisionView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = DriverProfileSerializer

    def post(self, request, driver_id, action):
        driver = DriverProfile.objects.filter(pk=driver_id).select_related("user").first()
        if driver is None:
            raise ApiError("Driver not found", code="not_found", status_code=404)
        before = {
            "kyc_status": driver.kyc_status,
            "approval_status": driver.approval_status,
        }
        if action == "approve":
            approve_driver(driver)
            notify_user(
                driver.user,
                type="kyc",
                title="You are approved",
                body="Your KYC is verified. Go online to start receiving trips.",
            )
        elif action == "reject":
            reason = (request.data.get("reason") or "").strip()
            if not reason:
                raise ApiError(
                    "A rejection reason is required",
                    code="validation_error",
                    status_code=400,
                )
            driver.kyc_status = DriverProfile.KYC_REJECTED
            driver.approval_status = DriverProfile.APPROVAL_PENDING
            driver.rejection_reason = reason[:240]
            driver.reviewed_at = timezone.now()
            driver.online_state = DriverProfile.ONLINE_OFFLINE
            driver.save()
            notify_user(
                driver.user,
                type="kyc",
                title="KYC needs attention",
                body=reason[:500],
            )
        elif action == "suspend":
            driver.approval_status = DriverProfile.APPROVAL_SUSPENDED
            driver.online_state = DriverProfile.ONLINE_OFFLINE
            driver.save(update_fields=["approval_status", "online_state", "updated_at"])
        else:
            raise ApiError("Unknown action", code="not_found", status_code=404)
        audit(
            actor=request.user,
            action=f"driver.{action}",
            entity=driver,
            before=before,
            after={
                "kyc_status": driver.kyc_status,
                "approval_status": driver.approval_status,
            },
        )
        return Response(DriverProfileSerializer(driver).data)


class OpsCustomerListView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = UserSerializer

    def get(self, request):
        qs = (
            User.objects.filter(role=User.Role.CUSTOMER)
            .annotate(bookings_count=Count("bookings"))
            .order_by("-created_at")
        )
        q = (request.query_params.get("q") or "").strip()
        if q:
            qs = qs.filter(
                Q(email__icontains=q)
                | Q(first_name__icontains=q)
                | Q(last_name__icontains=q)
                | Q(phone__icontains=q)
            )
        return Response(
            _paginate(
                request,
                qs,
                lambda items: [
                    {
                        "id": str(u.id),
                        "email": u.email,
                        "name": u.full_name,
                        "phone": u.phone,
                        "bookings_count": u.bookings_count,
                        "is_active": u.is_active,
                        "created_at": u.created_at,
                    }
                    for u in items
                ],
            )
        )


class OpsFinanceSummaryView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = PayoutSerializer

    def get(self, request):
        start = _range_start(request.query_params.get("range", "today"))
        completed = Booking.objects.filter(
            status=Booking.Status.COMPLETED, completed_at__gte=start
        )
        entries = CommissionEntry.objects.filter(created_at__gte=start)
        return Response(
            {
                "range": request.query_params.get("range", "today"),
                "trips": completed.count(),
                "gross_paise": completed.aggregate(total=Sum("final_fare_paise"))[
                    "total"
                ]
                or 0,
                "commission_paise": entries.aggregate(total=Sum("platform_paise"))[
                    "total"
                ]
                or 0,
                "driver_paise": entries.aggregate(total=Sum("driver_paise"))["total"]
                or 0,
                "payouts_pending_paise": Payout.objects.filter(
                    status__in=[Payout.Status.PENDING, Payout.Status.PROCESSING]
                ).aggregate(total=Sum("amount_paise"))["total"]
                or 0,
                "payouts_paid_paise": Payout.objects.filter(
                    status=Payout.Status.PAID, paid_at__gte=start
                ).aggregate(total=Sum("amount_paise"))["total"]
                or 0,
            }
        )


class OpsPayoutListView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = PayoutSerializer

    def get(self, request):
        qs = Payout.objects.select_related("driver__user").order_by("-created_at")
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"])
        return Response(
            _paginate(
                request,
                qs,
                lambda items: [
                    {
                        **PayoutSerializer(p).data,
                        "id": str(p.id),
                        "driver": p.driver.user.full_name,
                        "driver_email": p.driver.user.email,
                    }
                    for p in items
                ],
            )
        )


class OpsPayoutMarkPaidView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = PayoutSerializer

    def post(self, request, payout_id):
        payout = Payout.objects.filter(pk=payout_id).select_related("driver__user").first()
        if payout is None:
            raise ApiError("Payout not found", code="not_found", status_code=404)
        if payout.status == Payout.Status.PAID:
            raise ApiError(
                "Payout already marked paid",
                code="illegal_transition",
                status_code=409,
            )
        payout.status = Payout.Status.PAID
        payout.paid_at = timezone.now()
        payout.batch_ref = request.data.get("batch_ref") or payout.batch_ref
        payout.save(update_fields=["status", "paid_at", "batch_ref", "updated_at"])
        audit(actor=request.user, action="payout.paid", entity=payout)
        notify_user(
            payout.driver.user,
            type="payout",
            title="Payout sent",
            body=f"₹{payout.amount_paise / 100:.2f} is on its way to your bank.",
            data={"payout_id": str(payout.id)},
        )
        return Response(PayoutSerializer(payout).data)


class OpsPromoSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromoCampaign
        fields = (
            "id",
            "code",
            "kind",
            "value",
            "max_discount_paise",
            "min_fare_paise",
            "usage_limit",
            "per_user_limit",
            "used_count",
            "valid_from",
            "valid_to",
            "is_active",
            "created_at",
        )
        read_only_fields = ("id", "used_count", "created_at")


class OpsPromoListCreateView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = OpsPromoSerializer

    def get(self, request):
        promos = PromoCampaign.objects.order_by("-created_at")
        return Response(OpsPromoSerializer(promos, many=True).data)

    def post(self, request):
        serializer = OpsPromoSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        promo = serializer.save(code=serializer.validated_data["code"].upper())
        audit(actor=request.user, action="promo.create", entity=promo)
        return Response(
            OpsPromoSerializer(promo).data, status=status.HTTP_201_CREATED
        )


class OpsPromoDetailView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = OpsPromoSerializer

    def patch(self, request, promo_id):
        promo = PromoCampaign.objects.filter(pk=promo_id).first()
        if promo is None:
            raise ApiError("Promo not found", code="not_found", status_code=404)
        serializer = OpsPromoSerializer(promo, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        audit(actor=request.user, action="promo.update", entity=promo)
        return Response(OpsPromoSerializer(promo).data)


class OpsSettingsView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = UserSerializer

    def get(self, request):
        from apps.platform.models import SystemSetting

        return Response(
            {s.key: s.value for s in SystemSetting.objects.all()}
        )

    def put(self, request):
        from apps.platform.models import SystemSetting

        updated = {}
        for key, value in request.data.items():
            SystemSetting.objects.update_or_create(key=key, defaults={"value": value})
            updated[key] = value
        audit(actor=request.user, action="settings.update", entity=request.user, after=updated)
        return Response(updated)


class OpsTicketListView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = UserSerializer

    def get(self, request):
        qs = SupportTicket.objects.select_related("customer", "booking").order_by(
            "-created_at"
        )
        if request.query_params.get("status"):
            qs = qs.filter(status=request.query_params["status"])
        return Response(
            _paginate(
                request,
                qs,
                lambda items: [
                    {
                        "id": str(t.id),
                        "customer": t.customer.email,
                        "booking_id": str(t.booking_id) if t.booking_id else None,
                        "category": t.category,
                        "subject": t.subject,
                        "status": t.status,
                        "priority": t.priority,
                        "created_at": t.created_at,
                    }
                    for t in items
                ],
            )
        )


class OpsTicketDetailView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = UserSerializer

    def get(self, request, ticket_id):
        ticket = SupportTicket.objects.filter(pk=ticket_id).select_related("customer").first()
        if ticket is None:
            raise ApiError("Ticket not found", code="not_found", status_code=404)
        return Response(
            {
                "id": str(ticket.id),
                "customer": ticket.customer.email,
                "category": ticket.category,
                "subject": ticket.subject,
                "status": ticket.status,
                "priority": ticket.priority,
                "created_at": ticket.created_at,
                "messages": [
                    {
                        "id": str(m.id),
                        "author": "customer"
                        if m.author_id == ticket.customer_id
                        else "ops",
                        "body": m.body,
                        "created_at": m.created_at,
                    }
                    for m in ticket.messages.order_by("created_at")
                ],
            }
        )

    def post(self, request, ticket_id):
        ticket = SupportTicket.objects.filter(pk=ticket_id).first()
        if ticket is None:
            raise ApiError("Ticket not found", code="not_found", status_code=404)
        body = (request.data.get("message") or "").strip()
        if not body:
            raise ApiError(
                "Message body is required", code="validation_error", status_code=400
            )
        SupportMessage.objects.create(ticket=ticket, author=request.user, body=body)
        if request.data.get("status") in dict(SupportTicket.Status.choices):
            ticket.status = request.data["status"]
            ticket.save(update_fields=["status", "updated_at"])
        notify_user(
            ticket.customer,
            type="support",
            title="Support replied",
            body=body[:120],
            data={"ticket_id": str(ticket.id)},
        )
        return Response({"status": ticket.status})


class OpsAuditListView(APIView):
    permission_classes = [IsStaffUser]
    serializer_class = UserSerializer

    def get(self, request):
        qs = AuditLog.objects.order_by("-at")
        if request.query_params.get("entity"):
            qs = qs.filter(entity_type=request.query_params["entity"])
        return Response(
            _paginate(
                request,
                qs,
                lambda items: [
                    {
                        "id": row.id,
                        "actor_role": row.actor_role,
                        "actor_id": row.actor_id,
                        "action": row.action,
                        "entity_type": row.entity_type,
                        "entity_id": row.entity_id,
                        "at": row.at,
                    }
                    for row in items
                ],
            )
        )


class OpsAnalyticsView(APIView):
    """Daily revenue/trip trend + category mix for the ops dashboard."""

    permission_classes = [IsStaffUser]
    serializer_class = BookingSerializer

    def get(self, request):
        range_key = request.query_params.get("range", "week")
        start = _range_start(range_key)
        days = 7 if range_key == "week" else (30 if range_key == "month" else 1)
        entries = CommissionEntry.objects.filter(created_at__gte=start)
        rows = (
            entries.annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(
                trips=Count("id"),
                gross=Sum("booking__final_fare_paise"),
                commission=Sum("platform_paise"),
                net=Sum("driver_paise"),
            )
            .order_by("day")
        )
        by_day = {row["day"].isoformat(): row for row in rows}
        series = []
        for offset in range(days - 1, -1, -1):
            day = (timezone.localdate() - timedelta(days=offset)).isoformat()
            row = by_day.get(day)
            series.append(
                {
                    "date": day,
                    "trips": (row["trips"] if row else 0) or 0,
                    "revenue_paise": (row["gross"] if row else 0) or 0,
                    "commission_paise": (row["commission"] if row else 0) or 0,
                    "driver_paise": (row["net"] if row else 0) or 0,
                }
            )
        totals = entries.aggregate(
            trips=Count("id"),
            revenue=Sum("booking__final_fare_paise"),
            commission=Sum("platform_paise"),
            driver=Sum("driver_paise"),
        )
        top = (
            entries.values("booking__service_category__name")
            .annotate(
                trips=Count("id"),
                revenue=Sum("booking__final_fare_paise"),
            )
            .order_by("-revenue")[:5]
        )
        return Response(
            {
                "range": range_key,
                "series": series,
                "totals": {
                    "trips": totals["trips"] or 0,
                    "revenue_paise": totals["revenue"] or 0,
                    "commission_paise": totals["commission"] or 0,
                    "driver_paise": totals["driver"] or 0,
                },
                "top_categories": [
                    {
                        "name": row["booking__service_category__name"],
                        "trips": row["trips"],
                        "revenue_paise": row["revenue"] or 0,
                    }
                    for row in top
                ],
            }
        )
