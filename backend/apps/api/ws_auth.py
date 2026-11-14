"""WebSocket JWT auth + topic authorization."""
from __future__ import annotations

from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.middleware import BaseMiddleware
from django.contrib.auth.models import AnonymousUser


@database_sync_to_async
def _user_from_token(token: str):
    from rest_framework_simplejwt.authentication import JWTAuthentication
    from rest_framework_simplejwt.exceptions import InvalidToken

    try:
        auth = JWTAuthentication()
        validated = auth.get_validated_token(token)
        return auth.get_user(validated)
    except (InvalidToken, Exception):  # noqa: BLE001 - any failure = anonymous
        return AnonymousUser()


class TokenAuthMiddleware(BaseMiddleware):
    """Resolve `?token=<access>` (or Sec-WebSocket-Protocol) to `scope['user']`."""

    async def __call__(self, scope, receive, send):
        token = ""
        query = parse_qs(scope.get("query_string", b"").decode())
        if "token" in query:
            token = query["token"][0]
        if not token:
            protocols = dict(scope.get("headers") or [])
            header = protocols.get(b"sec-websocket-protocol", b"").decode()
            token = header.strip()
        scope = dict(scope)
        scope["user"] = (
            await _user_from_token(token) if token else AnonymousUser()
        )
        return await super().__call__(scope, receive, send)
