import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';

void main() {
  test('DriverOffer parses the live backend shape', () {
    final offer = DriverOffer.fromJson({
      'id': 'offer-1',
      'booking_id': 'bk-1',
      'status': 'offered',
      'expires_at': '2026-11-15T10:00:15Z',
      'pickup': {'lat': 12.9352, 'lng': 77.6245, 'address': 'Koramangala'},
      'drop': {'lat': 12.9716, 'lng': 77.5946, 'address': 'MG Road'},
      'distance_m': 5184,
      'pickup_eta_s': 240,
      'fare_paise': 14213,
      'surge_multiplier': 1.2,
      'service_category': {'code': 'auto', 'kind': 'ride', 'name': 'Auto'},
      'booking_type': 'goods',
      'kind': 'goods',
      'customer_first_name': 'Aarav',
      'goods': {
        'goods_type': 'Furniture',
        'weight_kg': 120,
        'needs_loading_help': true,
      },
      'dev_otp_hint': '4821',
    });
    expect(offer.serviceCategoryCode, 'auto');
    expect(offer.serviceCategoryName, 'Auto');
    expect(offer.kind, OfferKind.goods);
    expect(offer.goodsType, 'Furniture');
    expect(offer.weightKg, 120);
    expect(offer.needsLoadingHelp, isTrue);
    expect(offer.devOtpHint, '4821');
    expect(offer.surgeMultiplier, 1.2);
  });

  test('PartnerProfile parses nested user + acceptance + online state', () {
    final profile = PartnerProfile.fromJson({
      'id': 'drv-1',
      'user': {
        'id': 'u-1',
        'email': 'partner@zuum.in',
        'first_name': 'Ravi',
        'last_name': 'Kumar',
        'phone': '9845012345',
        'phone_verified': false,
        'role': 'driver',
      },
      'licence_number': 'KA0120180012345',
      'kyc_status': 'approved',
      'approval_status': 'active',
      'rating_avg': 4.8,
      'rating_count': 126,
      'online_state': 'available',
      'languages': ['Kannada', 'English'],
      'acceptance_rate': 92.5,
      'document_count': 3,
      'required_document_count': 3,
    });
    expect(profile.fullName, 'Ravi Kumar');
    expect(profile.email, 'partner@zuum.in');
    expect(profile.isApproved, isTrue);
    expect(profile.acceptanceRate, 92.5);
    expect(profile.documentCount, 3);
    expect(profile.onlineState, 'available');
  });

  test('KycDocumentInfo maps live statuses', () {
    final verified = KycDocumentInfo.fromJson({
      'id': 'doc-1',
      'type': 'licence',
      'status': 'verified',
    });
    expect(verified.status, KycStatus.approved);
    final pending = KycDocumentInfo.fromJson({
      'id': 'doc-2',
      'type': 'rc',
      'status': 'pending',
    });
    expect(pending.status, KycStatus.submitted);
  });

  test('PartnerTrip parses live status/route/otp hint', () {
    final trip = PartnerTrip.fromJson({
      'booking_id': 'bk-1',
      'kind': 'goods',
      'status': 'IN_PROGRESS',
      'pickup': {'lat': 12.93, 'lng': 77.62, 'address': 'A'},
      'drop': {'lat': 12.97, 'lng': 77.59, 'address': 'B'},
      'distance_m': 4800,
      'quoted_fare_paise': 20000,
      'fare_paise': 20000,
      'commission_paise': 4000,
      'earning_paise': 16000,
      'service_category_name': '3W Cargo',
      'customer_first_name': 'Aarav',
      'customer_phone_masked': '98450 •••11',
      'payment_method': 'cash',
      'payment_state': 'paid',
      'goods_type': 'Furniture',
      'needs_loading_help': true,
      'route': {
        'distance_m': 4800,
        'duration_s': 900,
        'geometry': [
          {'lat': 12.93, 'lng': 77.62},
          {'lat': 12.97, 'lng': 77.59},
        ],
        'provider': 'valhalla',
        'degraded': false,
      },
      'dev_otp_hint': '4821',
    });
    expect(trip.status, PartnerTripStatus.inProgress);
    expect(trip.kind, OfferKind.goods);
    expect(trip.route?.provider, 'valhalla');
    expect(trip.devOtpHint, '4821');
    expect(trip.earningPaise, 16000);
  });
}
