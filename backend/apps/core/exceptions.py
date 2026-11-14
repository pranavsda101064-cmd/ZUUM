"""Frozen error envelope: `{code, message, details?}` for every failure."""
from __future__ import annotations

from typing import Any

from rest_framework import status
from rest_framework.exceptions import APIException, Throttled, ValidationError
from rest_framework.response import Response
from rest_framework.views import exception_handler as drf_exception_handler


class ApiError(APIException):
    """Domain error with a stable machine code."""

    def __init__(
        self,
        message: str,
        *,
        code: str = "error",
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: Any | None = None,
    ) -> None:
        self.status_code = status_code
        self.code = code
        self.message = message
        self.details = details
        super().__init__(detail=message, code=code)


def error(code: str, message: str, *, status_code: int = 400, details=None):
    raise ApiError(message, code=code, status_code=status_code, details=details)


def illegal_transition(message: str = "This action is not valid for the current state."):
    error("illegal_transition", message, status_code=409)


def not_found(message: str = "Not found"):
    error("not_found", message, status_code=404)


def _flatten_validation(detail: Any) -> str:
    if isinstance(detail, dict):
        for key, value in detail.items():
            text = _flatten_validation(value)
            if text:
                return f"{key}: {text}" if key != "non_field_errors" else text
    if isinstance(detail, list) and detail:
        return _flatten_validation(detail[0])
    if detail:
        return str(detail)
    return "Validation failed"


def api_exception_handler(exc, context) -> Response | None:
    if isinstance(exc, ApiError):
        payload: dict[str, Any] = {"code": exc.code, "message": exc.message}
        if exc.details is not None:
            payload["details"] = exc.details
        return Response(payload, status=exc.status_code)

    if isinstance(exc, ValidationError):
        return Response(
            {
                "code": "validation_error",
                "message": _flatten_validation(exc.detail),
                "details": exc.detail,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    if isinstance(exc, Throttled):
        return Response(
            {
                "code": "rate_limited",
                "message": f"Too many requests. Retry in {int(exc.wait or 0)} s.",
                "details": {"retry_after": exc.wait},
            },
            status=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    response = drf_exception_handler(exc, context)
    if response is None:
        return None

    code = getattr(exc, "default_code", None) or "error"
    codes = exc.get_codes() if hasattr(exc, "get_codes") else None
    if isinstance(codes, str):
        code = codes
    elif isinstance(codes, list) and codes:
        code = str(codes[0])

    detail = response.data
    message = detail.get("detail") if isinstance(detail, dict) else None
    response.data = {
        "code": code,
        "message": str(message) if message else _flatten_validation(detail),
    }
    return response
