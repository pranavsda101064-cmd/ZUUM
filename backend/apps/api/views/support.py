"""Support, safety (SOS), notifications and reviews."""
from __future__ import annotations

from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.api.serializers import (
    NotificationSerializer,
    ReviewSerializer,
    SupportTicketSerializer,
)
from apps.bookings.models import Booking, Review
from apps.core.exceptions import ApiError
from apps.core.notifications import notify_user
from apps.platform.models import Notification, SosAlert, SupportMessage, SupportTicket

SUPPORT_TOPICS = [
    {"code": "fare", "title": "Fare & payment", "description": "Charges, receipts and refunds"},
    {"code": "trip", "title": "Trip issue", "description": "Route, driver or vehicle concerns"},
    {"code": "safety", "title": "Safety", "description": "Report an incident or unsafe behaviour"},
    {"code": "account", "title": "Account", "description": "Profile, wallet and access"},
    {"code": "goods", "title": "Goods & POD", "description": "Shipment damage or proof of delivery"},
    {"code": "other", "title": "Something else", "description": "Anything not listed"},
]

HELPLINES = {
    "police": "100",
    "women_helpline": "1091",
    "zuum_sos": "+91 80 4000 0000",
}


class SupportTopicsView(APIView):
    serializer_class = SupportTicketSerializer
    def get(self, request):
        return Response(SUPPORT_TOPICS)


class SupportTicketListCreateView(APIView):
    serializer_class = SupportTicketSerializer
    def get(self, request):
        tickets = SupportTicket.objects.filter(customer=request.user).order_by(
            "-created_at"
        )
        return Response(SupportTicketSerializer(tickets, many=True).data)

    def post(self, request):
        serializer = SupportTicketSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        booking = serializer.validated_data.get("booking")
        if booking is not None and booking.customer_id != request.user.id:
            raise ApiError("Booking not found", code="not_found", status_code=404)
        ticket = serializer.save(customer=request.user)
        message = (request.data.get("message") or "").strip()
        if message:
            SupportMessage.objects.create(
                ticket=ticket, author=request.user, body=message
            )
        return Response(
            SupportTicketSerializer(ticket).data, status=status.HTTP_201_CREATED
        )


class SupportTicketDetailView(APIView):
    serializer_class = SupportTicketSerializer
    def get(self, request, ticket_id):
        ticket = SupportTicket.objects.filter(
            pk=ticket_id, customer=request.user
        ).first()
        if ticket is None:
            raise ApiError("Ticket not found", code="not_found", status_code=404)
        messages = ticket.messages.order_by("created_at")
        return Response(
            {
                **SupportTicketSerializer(ticket).data,
                "messages": [
                    {
                        "id": str(m.id),
                        "author": "you" if m.author_id == request.user.id else "support",
                        "body": m.body,
                        "created_at": m.created_at,
                    }
                    for m in messages
                ],
            }
        )


class SosView(APIView):
    serializer_class = NotificationSerializer
    def post(self, request):
        booking_id = request.data.get("booking_id")
        booking = None
        if booking_id:
            booking = Booking.objects.filter(
                pk=booking_id, customer=request.user
            ).first()
        alert = SosAlert.objects.create(
            booking=booking,
            customer=request.user,
            lat=request.data.get("lat"),
            lng=request.data.get("lng"),
        )
        notify_user(
            request.user,
            type="safety",
            title="SOS received",
            body="Our safety desk is calling you now. Stay on the line.",
            data={"alert_id": str(alert.id)},
        )
        return Response(
            {
                "alert_id": str(alert.id),
                "status": "escalated",
                "helplines": HELPLINES,
                "created_at": alert.created_at,
            },
            status=status.HTTP_201_CREATED,
        )


class NotificationListView(APIView):
    serializer_class = NotificationSerializer
    def get(self, request):
        qs = Notification.objects.filter(user=request.user).order_by("-created_at")
        if request.query_params.get("unread") in ("true", "1"):
            qs = qs.filter(read_at__isnull=True)
        page = max(1, int(request.query_params.get("page", 1) or 1))
        size = max(1, min(100, int(request.query_params.get("page_size", 20) or 20)))
        total = qs.count()
        unread = qs.filter(read_at__isnull=True).count()
        items = qs[(page - 1) * size : page * size]
        return Response(
            {
                "count": total,
                "unread_count": unread,
                "next": (
                    request.build_absolute_uri(f"?page={page + 1}")
                    if page * size < total
                    else None
                ),
                "previous": None,
                "results": NotificationSerializer(items, many=True).data,
            }
        )


class NotificationReadView(APIView):
    serializer_class = NotificationSerializer
    def post(self, request, notification_id):
        notification = Notification.objects.filter(
            pk=notification_id, user=request.user
        ).first()
        if notification is None:
            raise ApiError(
                "Notification not found", code="not_found", status_code=404
            )
        if notification.read_at is None:
            notification.read_at = timezone.now()
            notification.save(update_fields=["read_at"])
        return Response(NotificationSerializer(notification).data)


class MyReviewsView(APIView):
    serializer_class = ReviewSerializer
    def get(self, request):
        qs = Review.objects.filter(reviewer=request.user).select_related("booking")
        return Response(
            [
                {
                    "id": str(r.id),
                    "booking_id": str(r.booking_id),
                    "rating": r.rating,
                    "comment": r.comment,
                    "tags": r.tags,
                    "created_at": r.created_at,
                }
                for r in qs
            ]
        )
