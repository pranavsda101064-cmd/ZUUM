import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';

Future<MockApiAdapter> signedInCustomer() async {
  final api = MockApiAdapter(latency: Duration.zero);
  await api.register(
    email: 'route@zuum.in',
    password: 'zuum1234',
    firstName: 'Route',
    lastName: 'Tester',
  );
  return api;
}

const pickup = LocationPoint(
  lat: 12.9352,
  lng: 77.6245,
  address: 'Koramangala 5th Block',
);
const drop = LocationPoint(
  lat: 12.9716,
  lng: 77.5946,
  address: 'MG Road',
);

void main() {
  test('RouteInfo round-trips geometry and steps', () {
    final info = RouteInfo.fromJson({
      'distance_m': 5184,
      'duration_s': 848,
      'geometry': [
        {'lat': 12.9352, 'lng': 77.6245},
        {'lat': 12.9716, 'lng': 77.5946},
      ],
      'steps': [
        {
          'type': 9,
          'instruction': 'Turn right onto MG Road',
          'street': 'MG Road',
          'distance_m': 1200,
          'duration_s': 180,
          'begin_shape_index': 0,
          'end_shape_index': 1,
        }
      ],
      'provider': 'valhalla',
      'degraded': false,
      'toll': false,
    });
    expect(info.distanceM, 5184);
    expect(info.provider, 'valhalla');
    expect(info.degraded, isFalse);
    expect(info.geometry, hasLength(2));
    expect(info.steps.single.instruction, 'Turn right onto MG Road');
    final json = info.toJson();
    expect(json['steps'], hasLength(1));
    expect(json['geometry'], hasLength(2));
  });

  test('mock curved route is realistic', () {
    final route = mockCurvedRoute(pickup, drop);
    expect(route.geometry.length, greaterThan(12));
    expect(route.steps, hasLength(4));
    expect(route.provider, 'mock-valhalla');
    expect(route.degraded, isFalse);
    expect(route.durationS, greaterThan(0));
    final straight = MockData.haversineM(
      pickup.lat,
      pickup.lng,
      drop.lat,
      drop.lng,
    );
    expect(route.distanceM, greaterThan(straight));
  });

  test('quote and booking carry the routed geometry', () async {
    final api = await signedInCustomer();
    final quote = await api.quote(
      kind: ServiceKind.ride,
      serviceCategory: 'auto',
      pickup: pickup,
      drop: drop,
    );
    expect(quote.route, isNotNull);
    expect(quote.route!.geometry.length, greaterThan(12));
    expect(quote.route!.steps, isNotEmpty);

    final booking = await api.createBooking(
      quoteId: quote.id,
      serviceCategory: 'auto',
      pickup: pickup,
      drop: drop,
      paymentMethod: PaymentMethod.cash,
    );
    expect(booking.route, isNotNull);

    final dropRoute = await api.bookingRoute(booking.id);
    expect(dropRoute.leg, 'drop');
    expect(dropRoute.geometry, isNotEmpty);

    final pickupRoute = await api.bookingRoute(booking.id, leg: 'pickup');
    expect(pickupRoute.leg, 'pickup');
    expect(pickupRoute.provider, 'mock-valhalla');
  });

  test('booking parses the nested API contract shape', () {
    final booking = Booking.fromJson({
      'id': 'b-1',
      'type': 'ride',
      'status': 'ASSIGNED',
      'service_category': {'code': 'sedan', 'kind': 'ride', 'name': 'Sedan'},
      'pickup': {'lat': 12.9, 'lng': 77.6, 'address': 'Jayanagar'},
      'drop': {'lat': 12.97, 'lng': 77.59, 'address': 'MG Road'},
      'fare': {'quoted_paise': 24000, 'final_paise': null, 'currency': 'INR'},
      'payment_method': 'upi',
      'payment_state': 'unpaid',
      'created_at': '2026-11-14T10:00:00Z',
      'driver': {
        'id': 'd-1',
        'name': 'Ravi Kumar',
        'phone': '9845012345',
        'rating_avg': 4.8,
        'photo_url': null,
      },
      'vehicle': {
        'registration_number': 'KA05AB1234',
        'make': 'Bajaj',
        'color': 'Yellow',
        'category': 'auto',
      },
      'route': {
        'distance_m': 5184,
        'duration_s': 848,
        'geometry': [
          {'lat': 12.9, 'lng': 77.6},
          {'lat': 12.97, 'lng': 77.59},
        ],
        'provider': 'valhalla',
        'degraded': false,
      },
    });
    expect(booking.serviceCategoryCode, 'sedan');
    expect(booking.serviceCategoryName, 'Sedan');
    expect(booking.pickupAddress, 'Jayanagar');
    expect(booking.quotedFarePaise, 24000);
    expect(booking.paymentMethod, PaymentMethod.upi);
    expect(booking.driver?.name, 'Ravi Kumar');
    expect(booking.vehicle?.registrationNumber, 'KA05AB1234');
    expect(booking.route?.distanceM, 5184);
  });
}
