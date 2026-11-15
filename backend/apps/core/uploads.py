"""Upload validation for KYC + POD media."""
from __future__ import annotations

from apps.core.exceptions import ApiError


def validate_upload(
    file,
    *,
    field: str = "file",
    max_mb: int = 10,
    allowed_prefixes: tuple[str, ...] = ("image/",),
):
    if file is None:
        return
    size = getattr(file, "size", 0) or 0
    if size > max_mb * 1024 * 1024:
        raise ApiError(
            f"{field} must be smaller than {max_mb} MB",
            code="validation_error",
            status_code=400,
            details={field: "too_large"},
        )
    content_type = (getattr(file, "content_type", "") or "").lower()
    if allowed_prefixes and not any(
        content_type == prefix or content_type.startswith(prefix)
        for prefix in allowed_prefixes
    ):
        raise ApiError(
            f"{field} must be one of: {', '.join(allowed_prefixes)}",
            code="validation_error",
            status_code=400,
            details={field: "invalid_type"},
        )
