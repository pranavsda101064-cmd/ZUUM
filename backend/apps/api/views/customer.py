"""Customer profile + saved addresses."""
from __future__ import annotations

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import CustomerProfile, SavedAddress
from apps.api.serializers import CustomerProfileSerializer, SavedAddressSerializer


def _profile(user) -> CustomerProfile:
    profile, _ = CustomerProfile.objects.get_or_create(user=user)
    return profile


class CustomerMeView(APIView):
    serializer_class = CustomerProfileSerializer
    def get(self, request):
        return Response(CustomerProfileSerializer(_profile(request.user)).data)

    def put(self, request):
        profile = _profile(request.user)
        serializer = CustomerProfileSerializer(profile, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class AddressListCreateView(APIView):
    serializer_class = SavedAddressSerializer
    def get(self, request):
        addresses = _profile(request.user).addresses.order_by("-is_default", "created_at")
        return Response(SavedAddressSerializer(addresses, many=True).data)

    def post(self, request):
        profile = _profile(request.user)
        serializer = SavedAddressSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if serializer.validated_data.get("is_default"):
            profile.addresses.update(is_default=False)
        address = serializer.save(customer=profile)
        return Response(
            SavedAddressSerializer(address).data, status=status.HTTP_201_CREATED
        )


class AddressDetailView(APIView):
    serializer_class = SavedAddressSerializer
    def _get(self, request, address_id):
        return SavedAddress.objects.filter(
            pk=address_id, customer__user=request.user
        ).first()

    def patch(self, request, address_id):
        address = self._get(request, address_id)
        if address is None:
            return Response(
                {"code": "not_found", "message": "Address not found"},
                status=status.HTTP_404_NOT_FOUND,
            )
        serializer = SavedAddressSerializer(address, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        if serializer.validated_data.get("is_default"):
            SavedAddress.objects.filter(customer=address.customer).exclude(
                pk=address.pk
            ).update(is_default=False)
        serializer.save()
        return Response(serializer.data)

    def delete(self, request, address_id):
        address = self._get(request, address_id)
        if address is None:
            return Response(
                {"code": "not_found", "message": "Address not found"},
                status=status.HTTP_404_NOT_FOUND,
            )
        address.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)
