import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';

void main() {
  group('MockRealtimeService dispatch simulation', () {
    late MockApiAdapter api;
    late MockRealtimeService realtime;
    late AuthRepository repo;

    setUp(() {
      api = MockApiAdapter(latency: Duration.zero);
      realtime = MockRealtimeService(
        assignAfter: const Duration(seconds: 1),
        arriveAfter: const Duration(seconds: 1),
        eta: const Duration(seconds: 2),
        tripDuration: const Duration(seconds: 2),
        onEvent: api.applyRealtimeEvent,
      );
      repo = AuthRepository(api: api, storage: InMemoryTokenStorage());
    });

    tearDown(() => realtime.dispose());

    Future<Booking> createRide() async {
      await repo.register(
        email: 'sim@zuum.in',
        password: 'secret12',
        firstName: 'Sim',
        lastName: 'User',
      );
      return api.createBooking(
        quoteId: 'q',
        serviceCategory: 'sedan',
        pickup: const LocationPoint(
          lat: 12.9352,
          lng: 77.6245,
          address: 'Koramangala',
        ),
        drop: const LocationPoint(
          lat: 12.9719,
          lng: 77.6412,
          address: 'Indiranagar',
        ),
        paymentMethod: PaymentMethod.cash,
      );
    }

    test('walks the full lifecycle: assigned → arriving → in progress → completed',
        () async {
      final booking = await createRide();
      final events = <RealtimeEvent>[];
      final sub = realtime.watchBooking(booking).listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(events.map((e) => e.status), contains(BookingStatus.assigned));
      final assigned = events.firstWhere(
        (e) => e.status == BookingStatus.assigned,
      );
      expect(assigned.driver, isNotNull);
      expect(assigned.vehicle, isNotNull);
      expect(assigned.otp, hasLength(4));

      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(events.map((e) => e.status), contains(BookingStatus.driverArriving));

      // Trip auto-starts after the demo ETA.
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(events.map((e) => e.status), contains(BookingStatus.inProgress));

      await Future<void>.delayed(const Duration(milliseconds: 2300));
      final completed = events.last;
      expect(completed.status, BookingStatus.completed);
      expect(completed.finalFarePaise, booking.quotedFarePaise);

      // Events were mirrored into the stored booking (Activity stays accurate).
      final stored = await api.booking(booking.id);
      expect(stored.status, BookingStatus.completed);
      expect(stored.driver, isNotNull);

      await sub.cancel();
    });

    test('verifyOtp starts the trip early; wrong OTP is rejected', () async {
      final booking = await createRide();
      final events = <RealtimeEvent>[];
      final sub = realtime.watchBooking(booking).listen(events.add);

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      final assigned = events.firstWhere(
        (e) => e.status == BookingStatus.assigned,
      );

      await expectLater(
        realtime.verifyOtp(bookingId: booking.id, otp: '0000'),
        throwsA(isA<ArgumentError>()),
      );

      await realtime.verifyOtp(bookingId: booking.id, otp: assigned.otp!);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(events.map((e) => e.status), contains(BookingStatus.inProgress));
      await sub.cancel();
    });

    test('locations stream pings the driver moving toward the route', () async {
      final booking = await createRide();
      final locations = <DriverLocation>[];
      final sub = realtime.watchDriverLocation(booking).listen(locations.add);
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(locations, isNotEmpty);
      expect(locations.first.recordedAt, isNotNull);
      await sub.cancel();
    });

    test('stop() cancels the simulation', () async {
      final booking = await createRide();
      final events = <RealtimeEvent>[];
      final sub = realtime.watchBooking(booking).listen(events.add);
      realtime.stop(booking.id);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(events.where((e) => e.status == BookingStatus.assigned), isEmpty);
      await sub.cancel();
    });
  });

  group('payments & wallet (mock)', () {
    late MockApiAdapter api;
    late AuthRepository repo;

    setUp(() {
      api = MockApiAdapter(latency: Duration.zero);
      repo = AuthRepository(api: api, storage: InMemoryTokenStorage());
    });

    test('wallet starts with the demo balance and tops up', () async {
      await repo.register(
        email: 'pay@zuum.in',
        password: 'secret12',
        firstName: 'P',
        lastName: 'U',
      );
      var wallet = await api.wallet();
      expect(wallet.balancePaise, 15000);

      wallet = await api.topUpWallet(
        amountPaise: 20000,
        method: PaymentMethod.upi,
      );
      expect(wallet.balancePaise, 35000);

      final tx = await api.walletTransactions();
      expect(tx.results, hasLength(2));
      expect(tx.results.first.type, WalletTxType.topup); // newest first
    });

    test('payBooking with wallet debits; insufficient balance is rejected',
        () async {
      await repo.register(
        email: 'wallet@zuum.in',
        password: 'secret12',
        firstName: 'W',
        lastName: 'U',
      );
      final booking = await api.createBooking(
        quoteId: 'q',
        serviceCategory: 'sedan',
        pickup: const LocationPoint(lat: 12.9352, lng: 77.6245, address: 'A'),
        drop: const LocationPoint(lat: 12.9719, lng: 77.6412, address: 'B'),
        paymentMethod: PaymentMethod.wallet,
      );
      // Bump the stored booking to completed (as the simulator would).
      api.applyRealtimeEvent(
        RealtimeEvent(
          bookingId: booking.id,
          status: BookingStatus.completed,
          finalFarePaise: booking.quotedFarePaise,
        ),
      );

      // Demo balance is ₹150 — a sedan trip should exceed it.
      if (booking.quotedFarePaise > 15000) {
        await expectLater(
          api.payBooking(bookingId: booking.id, method: PaymentMethod.wallet),
          throwsA(
            isA<ApiException>()
                .having((e) => e.code, 'code', 'insufficient_balance'),
          ),
        );
      }

      await api.topUpWallet(amountPaise: 500000, method: PaymentMethod.upi);
      final paid = await api.payBooking(
        bookingId: booking.id,
        method: PaymentMethod.wallet,
        tipPaise: 2000,
      );
      expect(paid.paymentState, PaymentState.paid);
      expect(paid.finalFarePaise, booking.quotedFarePaise + 2000);

      final wallet = await api.wallet();
      expect(
        wallet.balancePaise,
        515000 - booking.quotedFarePaise - 2000,
      );
    });

    test('payBooking rejects unpaid trips', () async {
      await repo.register(
        email: 'early@zuum.in',
        password: 'secret12',
        firstName: 'E',
        lastName: 'L',
      );
      final booking = await api.createBooking(
        quoteId: 'q',
        serviceCategory: 'auto',
        pickup: const LocationPoint(lat: 12.93, lng: 77.62, address: 'A'),
        drop: const LocationPoint(lat: 12.95, lng: 77.64, address: 'B'),
        paymentMethod: PaymentMethod.cash,
      );
      await expectLater(
        api.payBooking(bookingId: booking.id, method: PaymentMethod.cash),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'illegal_transition')),
      );
    });

    test('MockPaymentGateway enforces the minimum top-up', () async {
      final gateway = MockPaymentGateway(latency: Duration.zero);
      final bad = await gateway.topUp(amountPaise: 500, method: PaymentMethod.upi);
      expect(bad.success, isFalse);
      final good = await gateway.topUp(
        amountPaise: 10000,
        method: PaymentMethod.upi,
      );
      expect(good.success, isTrue);
      expect(good.transactionId, isNotNull);
    });
  });

  group('goods bookings & promos', () {
    late MockApiAdapter api;
    late AuthRepository repo;

    setUp(() {
      api = MockApiAdapter(latency: Duration.zero);
      repo = AuthRepository(api: api, storage: InMemoryTokenStorage());
    });

    test('goods booking stores shipment fields and a delivery OTP', () async {
      await repo.register(
        email: 'goods@zuum.in',
        password: 'secret12',
        firstName: 'G',
        lastName: 'U',
      );
      final booking = await api.createBooking(
        quoteId: 'q',
        serviceCategory: 'ace',
        pickup: const LocationPoint(lat: 12.93, lng: 77.62, address: 'Pickup'),
        drop: const LocationPoint(lat: 12.95, lng: 77.64, address: 'Drop'),
        paymentMethod: PaymentMethod.cash,
        goodsType: 'Furniture',
        weightKg: 120,
        needsLoadingHelp: true,
        senderName: 'Asha',
        senderPhone: '+919800000011',
        receiverName: 'Rahul',
        receiverPhone: '+919800000012',
      );
      expect(booking.type, BookingType.goods);
      expect(booking.goodsType, 'Furniture');
      expect(booking.weightKg, 120);
      expect(booking.needsLoadingHelp, isTrue);
      expect(booking.receiverName, 'Rahul');
      expect(booking.otp, '4321');

      // Loading help adds a charge (server-side).
      expect(booking.quotedFarePaise, greaterThan(5000));
    });

    test('loading help increases the quote', () async {
      await repo.register(
        email: 'quote@zuum.in',
        password: 'secret12',
        firstName: 'Q',
        lastName: 'U',
      );
      final plain = await api.quote(
        kind: ServiceKind.goods,
        serviceCategory: 'ace',
        pickup: const LocationPoint(lat: 12.93, lng: 77.62),
        drop: const LocationPoint(lat: 12.95, lng: 77.64),
      );
      final withHelp = await api.quote(
        kind: ServiceKind.goods,
        serviceCategory: 'ace',
        pickup: const LocationPoint(lat: 12.93, lng: 77.62),
        drop: const LocationPoint(lat: 12.95, lng: 77.64),
        needsLoadingHelp: true,
      );
      // Loading charge lives in the mock breakdown only via total.
      expect(
        withHelp.breakdown.totalPaise,
        greaterThan(plain.breakdown.totalPaise),
      );
    });

    test('promo validation and discount math', () async {
      await repo.register(
        email: 'promo@zuum.in',
        password: 'secret12',
        firstName: 'P',
        lastName: 'R',
      );
      final promo = await api.validatePromo(
        code: 'zuum50',
        farePaise: 20000,
        serviceCategory: 'sedan',
      );
      expect(promo.discountFor(20000), 5000); // 50% capped at ₹50

      await expectLater(
        api.validatePromo(
          code: 'NOPE',
          farePaise: 20000,
          serviceCategory: 'sedan',
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_promo')),
      );

      await expectLater(
        api.validatePromo(
          code: 'ZUUM50',
          farePaise: 5000,
          serviceCategory: 'sedan',
        ),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'promo_min_fare')),
      );
    });

    test('goods delivery OTP verifies and wrong codes fail', () async {
      await repo.register(
        email: 'pod@zuum.in',
        password: 'secret12',
        firstName: 'D',
        lastName: 'L',
      );
      final booking = await api.createBooking(
        quoteId: 'q',
        serviceCategory: 'goods_2w',
        pickup: const LocationPoint(lat: 12.93, lng: 77.62, address: 'A'),
        drop: const LocationPoint(lat: 12.95, lng: 77.64, address: 'B'),
        paymentMethod: PaymentMethod.cash,
        goodsType: 'Documents',
        weightKg: 2,
        receiverName: 'X',
        receiverPhone: '+919800000013',
      );
      await expectLater(
        api.verifyOtp(bookingId: booking.id, otp: '1111'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_otp')),
      );
      await api.verifyOtp(bookingId: booking.id, otp: '4321');
    });
  });

  group('notifications & support (mock)', () {
    late MockApiAdapter api;
    late AuthRepository repo;

    setUp(() {
      api = MockApiAdapter(latency: Duration.zero);
      repo = AuthRepository(api: api, storage: InMemoryTokenStorage());
    });

    test('notifications seed, mark read; support tickets create', () async {
      await repo.register(
        email: 'ntf@zuum.in',
        password: 'secret12',
        firstName: 'N',
        lastName: 'T',
      );
      final page = await api.notifications();
      expect(page.results.length, greaterThanOrEqualTo(2));
      expect(page.results.first.isUnread, isTrue);

      await api.markNotificationRead(page.results.first.id);
      final after = await api.notifications();
      expect(
        after.results.firstWhere((n) => n.id == page.results.first.id).isUnread,
        isFalse,
      );

      final topics = await api.supportTopics();
      expect(topics, isNotEmpty);

      final ticket = await api.createSupportTicket(
        subject: 'Lost umbrella',
        category: 'lost-item',
        body: 'Left it in the auto.',
      );
      expect(ticket.status, 'open');
      expect(ticket.messages, hasLength(1));
      final tickets = await api.supportTickets();
      expect(tickets.results, hasLength(1));
    });
  });
}
