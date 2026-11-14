from django.urls import path

from .consumers import TopicConsumer

websocket_urlpatterns = [
    path("ws/<str:topic>/<str:identifier>/", TopicConsumer.as_asgi()),
]
