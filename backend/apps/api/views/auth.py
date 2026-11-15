"""Auth endpoints: JWT session, refresh rotation, password reset."""
from __future__ import annotations

from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.tokens import PasswordResetTokenGenerator
from django.core import signing
from django.core.mail import send_mail
from django.utils import timezone
from rest_framework import serializers, status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from apps.accounts.models import CustomerProfile
from apps.api.serializers import (
    LoginSerializer,
    LogoutSerializer,
    PasswordForgotSerializer,
    PasswordResetSerializer,
    UserSerializer,
)

User = get_user_model()


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(min_length=6, write_only=True)
    first_name = serializers.CharField(max_length=80)
    last_name = serializers.CharField(max_length=80, allow_blank=True)
    phone = serializers.CharField(max_length=20, required=False, allow_blank=True)

    def validate_email(self, value: str) -> str:
        value = value.strip().lower()
        if User.objects.filter(email=value).exists():
            raise serializers.ValidationError(
                "An account with this email already exists"
            )
        return value

    def validate_password(self, value: str) -> str:
        if len(value) < 6:
            raise serializers.ValidationError(
                "Password must be at least 6 characters"
            )
        return value


def issue_tokens(user) -> dict:
    refresh = RefreshToken.for_user(user)
    refresh["role"] = user.role
    access = refresh.access_token
    access["role"] = user.role
    return {"access": str(access), "refresh": str(refresh)}


class RegisterView(APIView):
    serializer_class = RegisterSerializer
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = User.objects.create_user(
            email=data["email"],
            password=data["password"],
            first_name=data["first_name"].strip(),
            last_name=data.get("last_name", "").strip(),
            phone=data.get("phone", "").strip(),
            role=User.Role.CUSTOMER,
        )
        CustomerProfile.objects.get_or_create(user=user)
        return Response(
            {"user": UserSerializer(user).data}, status=status.HTTP_201_CREATED
        )


class LoginView(APIView):
    serializer_class = LoginSerializer
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        password = request.data.get("password") or ""
        user = User.objects.filter(email=email, is_active=True).first()
        if user is None or not user.check_password(password):
            return Response(
                {"code": "invalid_credentials", "message": "Incorrect email or password"},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        user.last_login = timezone.now()
        user.save(update_fields=["last_login"])
        payload = issue_tokens(user)
        payload["user"] = UserSerializer(user).data
        return Response(payload)


class RotatingTokenRefreshView(TokenRefreshView):
    permission_classes = [AllowAny]


class LogoutView(APIView):
    serializer_class = LogoutSerializer
    permission_classes = [AllowAny]

    def post(self, request):
        token = request.data.get("refresh")
        if token:
            try:
                RefreshToken(token).blacklist()
            except Exception:  # noqa: BLE001 - logout is idempotent
                pass
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    serializer_class = UserSerializer
    def get(self, request):
        return Response({"user": UserSerializer(request.user).data})

    def put(self, request):
        user = request.user
        changed = []
        for field in ("first_name", "last_name", "phone"):
            if field in request.data:
                setattr(user, field, str(request.data[field]).strip())
                changed.append(field)
        if changed:
            user.save(update_fields=changed)
        return Response({"user": UserSerializer(user).data})


class ForgotPasswordView(APIView):
    serializer_class = PasswordForgotSerializer
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        email = (request.data.get("email") or "").strip().lower()
        user = User.objects.filter(email=email, is_active=True).first()
        if user is not None:
            token = signing.dumps(
                {"uid": str(user.pk)},
                salt=settings.PASSWORD_RESET_SALT,
            )
            send_mail(
                "Reset your Zuum password",
                f"Use this token to reset your password.\n\nToken: {token}",
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class ResetPasswordView(APIView):
    serializer_class = PasswordResetSerializer
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        token = request.data.get("token") or ""
        password = request.data.get("password") or ""
        if len(password) < 6:
            return Response(
                {
                    "code": "validation_error",
                    "message": "Password must be at least 6 characters",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            payload = signing.loads(
                token,
                salt=settings.PASSWORD_RESET_SALT,
                max_age=settings.PASSWORD_RESET_TTL_SECONDS,
            )
        except (signing.BadSignature, signing.SignatureExpired):
            return Response(
                {"code": "invalid_token", "message": "Reset token is invalid or expired"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user = User.objects.filter(pk=payload.get("uid")).first()
        if user is None:
            return Response(
                {"code": "invalid_token", "message": "Reset token is invalid or expired"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.set_password(password)
        user.save(update_fields=["password"])
        return Response(status=status.HTTP_204_NO_CONTENT)
