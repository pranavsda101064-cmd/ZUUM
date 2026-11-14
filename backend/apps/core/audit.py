"""Immutable audit trail for sensitive mutations."""
from __future__ import annotations

from typing import Any


def audit(
    *,
    actor,
    action: str,
    entity: Any,
    before: dict | None = None,
    after: dict | None = None,
    ip: str | None = None,
):
    from apps.platform.models import AuditLog

    return AuditLog.objects.create(
        actor_id=getattr(actor, "id", None),
        actor_role=getattr(actor, "role", "system") or "system",
        action=action,
        entity_type=entity.__class__.__name__,
        entity_id=str(getattr(entity, "pk", "")),
        before=before or {},
        after=after or {},
        ip=ip,
    )
