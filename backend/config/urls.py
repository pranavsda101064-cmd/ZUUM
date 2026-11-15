"""URL configuration for Zuum.

REST surface: `/api/v1/` (consumer + partner + fleet).
Realtime: `/ws/{topic}/?token=`.
Schema: `/api/v1/schema/` + Swagger UI at `/api/v1/docs/`.
"""
from pathlib import Path

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.contrib.admin.views.decorators import staff_member_required
from django.http import FileResponse, Http404
from django.urls import include, path, re_path
from django.views.static import serve as static_serve
from drf_spectacular.views import (
    SpectacularAPIView,
    SpectacularSwaggerView,
)


def ops_console(request, path=""):
    root = Path(settings.OPS_CONSOLE_DIR).resolve()
    target = (root / path).resolve() if path else root / "index.html"
    if root not in target.parents and target != root:
        raise Http404
    if target.is_dir():
        target = target / "index.html"
    if not target.exists():
        target = root / "index.html"
    if not target.exists():
        raise Http404
    return FileResponse(target.open("rb"))


urlpatterns = [
    path("admin/", admin.site.urls),
    re_path(r"^ops-console(?:/(?P<path>.*))?$", ops_console),
    path("api/v1/", include("apps.api.urls")),
    path("api/v1/schema/", SpectacularAPIView.as_view(), name="schema"),
    path(
        "api/v1/docs/",
        SpectacularSwaggerView.as_view(url_name="schema"),
        name="swagger-ui",
    ),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    # KYC/POD files are private: only signed-in staff can open them.
    urlpatterns += [
        re_path(
            r"^media/(?P<path>.*)$",
            staff_member_required(static_serve),
            {"document_root": settings.MEDIA_ROOT},
        )
    ]
