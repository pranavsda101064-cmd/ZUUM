import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';

void main() {
  late MockApiAdapter api;
  late InMemoryTokenStorage storage;
  late AuthRepository repo;

  setUp(() {
    api = MockApiAdapter();
    storage = InMemoryTokenStorage();
    repo = AuthRepository(api: api, storage: storage);
  });

  group('auth', () {
    test('register issues a session and persists it', () async {
      final session = await repo.register(
        email: 'ravi@zuum.in',
        password: 'secret12',
        firstName: 'Ravi',
        lastName: 'Kumar',
      );
      expect(session.user.email, 'ravi@zuum.in');
      expect(session.user.fullName, 'Ravi Kumar');
      expect(session.user.role, UserRole.customer);
      expect(await storage.readSession(), isNotNull);
    });

    test('register rejects duplicate email with 409', () async {
      await repo.register(
        email: 'dup@zuum.in',
        password: 'secret12',
        firstName: 'A',
        lastName: 'B',
      );
      expect(
        () => repo.register(
          email: 'dup@zuum.in',
          password: 'secret12',
          firstName: 'C',
          lastName: 'D',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.code, 'code', 'already_exists'),
        ),
      );
    });

    test('login fails for unknown email and wrong password', () async {
      await expectLater(
        repo.login(email: 'ghost@zuum.in', password: 'secret12'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
      await repo.register(
        email: 'user@zuum.in',
        password: 'secret12',
        firstName: 'U',
        lastName: 'S',
      );
      await expectLater(
        repo.login(email: 'user@zuum.in', password: 'wrong-pass'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
      );
    });

    test('restoreSession refreshes a stored session', () async {
      await repo.register(
        email: 'restore@zuum.in',
        password: 'secret12',
        firstName: 'R',
        lastName: 'S',
      );
      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.user.email, 'restore@zuum.in');
    });

    test('restoreSession returns null after signOut', () async {
      await repo.register(
        email: 'bye@zuum.in',
        password: 'secret12',
        firstName: 'B',
        lastName: 'Y',
      );
      await repo.signOut();
      expect(await repo.restoreSession(), isNull);
      expect(await storage.readSession(), isNull);
    });

    test('me() requires an authenticated session', () async {
      await expectLater(
        repo.me(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('catalog & pricing', () {
    setUp(() async {
      await repo.register(
        email: 'blr@zuum.in',
        password: 'secret12',
        firstName: 'B',
        lastName: 'L',
      );
    });

    test('service categories are split by kind for Bengaluru', () async {
      final rides = await api.serviceCategories(city: 'blr', kind: ServiceKind.ride);
      final goods = await api.serviceCategories(city: 'blr', kind: ServiceKind.goods);
      expect(rides.map((c) => c.code), containsAll(['bike', 'auto', 'sedan', 'suv']));
      expect(goods.map((c) => c.code), containsAll(['goods_2w', 'goods_3w', 'ace', 'pickup', 'van', 'tempo']));
      expect(rides.every((c) => c.kind == ServiceKind.ride), isTrue);
      expect(goods.every((c) => c.kind == ServiceKind.goods), isTrue);
    });

    test('quote produces a sane fare breakdown', () async {
      final quote = await api.quote(
        kind: ServiceKind.ride,
        serviceCategory: 'sedan',
        pickup: const LocationPoint(lat: 12.9352, lng: 77.6245),
        drop: const LocationPoint(lat: 12.9719, lng: 77.6412),
      );
      final b = quote.breakdown;
      expect(quote.distanceM, greaterThan(1000));
      expect(b.totalPaise, greaterThan(0));
      expect(
        b.totalPaise,
        b.basePaise + b.distancePaise + b.timePaise + b.surgePaise + b.tollPaise +
            b.waitingPaise - b.discountPaise,
      );
      expect(quote.validUntil.isAfter(DateTime.now().toUtc()), isTrue);
    });

    test('quote rejects unknown category', () async {
      await expectLater(
        api.quote(
          kind: ServiceKind.ride,
          serviceCategory: 'rocket',
          pickup: const LocationPoint(lat: 12.9, lng: 77.6),
          drop: const LocationPoint(lat: 12.95, lng: 77.65),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('bookings', () {
    setUp(() async {
      await repo.register(
        email: 'trips@zuum.in',
        password: 'secret12',
        firstName: 'T',
        lastName: 'R',
      );
    });

    test('seeded bookings are visible and fetchable', () async {
      final page = await api.bookings();
      expect(page.results, hasLength(2));
      expect(page.count, 2);
      final first = await api.booking(page.results.first.id);
      expect(first.id, page.results.first.id);
      expect(first.status, BookingStatus.completed);
    });

    test('cancel flips status but completed bookings stay completed', () async {
      final page = await api.bookings();
      final active = page.results.firstWhere((b) => b.status == BookingStatus.completed);
      await expectLater(
        api.cancelBooking(active.id, reason: 'test'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
      expect((await api.booking(active.id)).status, BookingStatus.completed);
    });

    test('filter by status works', () async {
      final page = await api.bookings(status: 'COMPLETED');
      expect(page.results, isNotEmpty);
      expect(page.results.every((b) => b.status == BookingStatus.completed), isTrue);
    });

    test('createBooking produces a SEARCHING booking with a sane fare', () async {
      final booking = await api.createBooking(
        quoteId: 'quote-1',
        serviceCategory: 'sedan',
        pickup: const LocationPoint(
          lat: 12.9352,
          lng: 77.6245,
          address: 'Koramangala, Bengaluru',
        ),
        drop: const LocationPoint(
          lat: 12.9719,
          lng: 77.6412,
          address: 'Indiranagar, Bengaluru',
        ),
        paymentMethod: PaymentMethod.cash,
      );
      expect(booking.status, BookingStatus.searching);
      expect(booking.type, BookingType.ride);
      expect(booking.quotedFarePaise, greaterThan(0));
      expect(booking.driver, isNull);
      expect((await api.booking(booking.id)).id, booking.id);
    });

    test('createBooking rejects unknown category', () async {
      await expectLater(
        api.createBooking(
          quoteId: 'q',
          serviceCategory: 'rocket',
          pickup: const LocationPoint(lat: 12.9, lng: 77.6, address: 'A'),
          drop: const LocationPoint(lat: 12.95, lng: 77.65, address: 'B'),
          paymentMethod: PaymentMethod.upi,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400)),
      );
    });
  });

  group('place search (mock)', () {
    test('matches Bengaluru landmarks by name and address', () async {
      final search = MockPlaceSearch(latency: Duration.zero);
      final results = await search.search(
        'lalbagh',
        proximityLat: 12.97,
        proximityLng: 77.59,
      );
      expect(results, isNotEmpty);
      expect(results.first.name, contains('Lalbagh'));

      final byArea = await search.search(
        'whitefield',
        proximityLat: 12.97,
        proximityLng: 77.59,
      );
      expect(byArea.map((p) => p.name), contains('Whitefield'));

      final empty = await search.search(
        'zzzz-nowhere',
        proximityLat: 12.97,
        proximityLng: 77.59,
      );
      expect(empty, isEmpty);
    });
  });
}
