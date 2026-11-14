"""Admin registrations for the demo (ops can inspect everything)."""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import DriverProfile, FleetPartner, KycDocument, SavedAddress, User, Vehicle


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    ordering = ("email",)
    list_display = ("email", "first_name", "last_name", "role", "is_active")
    list_filter = ("role", "is_active")
    search_fields = ("email", "first_name", "last_name", "phone")
    fieldsets = (
        (None, {"fields": ("email", "password")}),
        ("Profile", {"fields": ("first_name", "last_name", "phone", "phone_verified")}),
        ("Role", {"fields": ("role", "is_active", "is_staff", "is_superuser")}),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("email", "first_name", "last_name", "password1", "password2", "role"),
            },
        ),
    )


admin.site.register(DriverProfile)
admin.site.register(FleetPartner)
admin.site.register(Vehicle)
admin.site.register(KycDocument)
admin.site.register(SavedAddress)
