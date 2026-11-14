"""Role-based DRF permissions (`user.role` claim / column)."""
from __future__ import annotations

from rest_framework.permissions import BasePermission


class HasRole(BasePermission):
    """Allow only the given role codes."""

    roles: tuple[str, ...] = ()

    def has_permission(self, request, view) -> bool:
        user = request.user
        if not user or not user.is_authenticated:
            return False
        if user.is_superuser:
            return True
        return getattr(user, "role", None) in self.roles


class IsCustomer(HasRole):
    roles = ("customer",)


class IsDriver(HasRole):
    roles = ("driver", "fleet_owner")


class IsFleetOwner(HasRole):
    roles = ("fleet_owner",)


class IsStaffUser(HasRole):
    roles = ("staff",)
