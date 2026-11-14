import 'package:flutter_test/flutter_test.dart';
import 'package:zuum_core/core.dart';

/// Helper: register a fresh driver and return the API (already authenticated).
Future<MockPartnerApi> registerDriver({
  Duration kycReviewDelay = Duration.zero,
  Duration offerExpiry = const Duration(seconds: 15),
}) async {
  final api = MockPartnerApi(
    latency: Duration.zero,
    kycReviewDelay: kycReviewDelay,
    offerExpiry: offerExpiry,
  );
  await api.register(
    email: 'captain@zuum.in',
    password: 'secret12',
    firstName: 'Ravi',
    lastName: 'Kumar',
    phone: '+919800000001',
  );
  return api;
}

/// Helper: complete KYC + add an Auto, making the driver ready to go online.
Future<PartnerVehicle> onboard(
  MockPartnerApi api, {
  String category = 'auto',
  String plate = 'KA 05 AB 1234',
}) async {
  await api.uploadDocument(type: KycDocType.licence, filePath: '/tmp/lic.jpg');
  await api.uploadDocument(type: KycDocType.rc, filePath: '/tmp/rc.jpg');
  await api.uploadDocument(type: KycDocType.insurance, filePath: '/tmp/ins.jpg');
  await api.submitKyc();
  return api.createVehicle(
    categoryCode: category,
    registrationNumber: plate,
    make: 'Bajaj',
    model: 'RE Auto',
    color: 'Yellow',
  );
}

Future<PartnerTrip> acceptedTrip(MockPartnerApi api) async {
  final offer = api.createSimulatedOffer();
  return api.acceptOffer(offer.id);
}

void main() {
  group('partner auth & profile', () {
    test('register creates a driver account', () async {
      final api = await registerDriver();
      final me = await api.me();
      expect(me.role, UserRole.driver);
      final profile = await api.profile();
      expect(profile.kycStatus, KycStatus.draft);
      expect(profile.approvalStatus, ApprovalStatus.pending);
      expect(profile.fullName, 'Ravi Kumar');
    });

    test('duplicate registration rejected; wrong password rejected', () async {
      final api = await registerDriver();
      await expectLater(
        api.register(
          email: 'captain@zuum.in',
          password: 'secret12',
          firstName: 'X',
          lastName: 'Y',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      await expectLater(
        api.login(email: 'captain@zuum.in', password: 'nope-nope'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'invalid_credentials')),
      );
    });
  });

  group('KYC', () {
    test('submit without required documents fails with the missing list',
        () async {
      final api = await registerDriver();
      await api.uploadDocument(type: KycDocType.licence, filePath: '/tmp/l');
      await expectLater(
        api.submitKyc(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'kyc_incomplete')
              .having(
                (e) => (e.details as Map)['missing'],
                'missing',
                containsAll(['rc', 'insurance']),
              ),
        ),
      );
    });

    test('submitted KYC waits for the review window, then approves', () async {
      final api = await registerDriver(
        kycReviewDelay: const Duration(hours: 1),
      );
      await onboard(api);
      final pending = await api.profile();
      expect(pending.kycStatus, KycStatus.submitted);
      expect(pending.isApproved, isFalse);

      final fast = await registerDriver(); // zero review delay
      await onboard(fast);
      final approved = await fast.profile();
      expect(approved.kycStatus, KycStatus.approved);
      expect(approved.approvalStatus, ApprovalStatus.active);
    });

    test('upload replaces an existing document type', () async {
      final api = await registerDriver();
      await api.uploadDocument(type: KycDocType.licence, filePath: '/a');
      await api.uploadDocument(type: KycDocType.licence, filePath: '/b');
      final docs = await api.documents();
      expect(docs.where((d) => d.type == KycDocType.licence), hasLength(1));
    });
  });

  group('vehicles & availability', () {
    test('vehicle creation validates category and duplicate plates', () async {
      final api = await registerDriver();
      await expectLater(
        api.createVehicle(
          categoryCode: 'rocket',
          registrationNumber: 'KA 01 AA 0001',
          make: 'X',
          model: 'Y',
          color: 'Z',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
      );
      await api.createVehicle(
        categoryCode: 'auto',
        registrationNumber: 'KA 01 AA 0001',
        make: 'Bajaj',
        model: 'RE',
        color: 'Yellow',
      );
      await expectLater(
        api.createVehicle(
          categoryCode: 'auto',
          registrationNumber: 'ka 01 aa 0001',
          make: 'Bajaj',
          model: 'RE',
          color: 'Yellow',
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
    });

    test('cannot go online before approval or without an active vehicle',
        () async {
      final slow = await registerDriver(
        kycReviewDelay: const Duration(hours: 1),
      );
      await onboard(slow);
      await expectLater(
        slow.setOnline(online: true),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_approved')),
      );

      final api = await registerDriver();
      await onboard(api);
      await api.setVehicleAvailability(
        vehicleId: (await api.vehicles()).first.id,
        isActive: false,
      );
      await expectLater(
        api.setOnline(online: true),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'vehicle_inactive'),
        ),
      );
    });

    test('approved driver with an active vehicle goes online', () async {
      final api = await registerDriver();
      await onboard(api);
      expect(await api.setOnline(online: true), isTrue);
      expect(api.onlineNow, isTrue);
      expect(await api.isOnline(), isTrue);
      await api.setOnline(online: false);
      expect(api.onlineNow, isFalse);
    });
  });

  group('offers & trip lifecycle', () {
    test('offers require being online', () async {
      final api = await registerDriver();
      await onboard(api);
      expect(() => api.createSimulatedOffer(),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'not_online')));

      await api.setOnline(online: true);
      final offer = api.createSimulatedOffer();
      expect(offer.devOtpHint, hasLength(4));
      expect(offer.farePaise, greaterThan(0));
      final pending = await api.pendingOffers();
      expect(pending.map((o) => o.id), contains(offer.id));
    });

    test('ride trip: accept → arrive → wrong OTP → verify → complete → earnings',
        () async {
      final api = await registerDriver();
      await onboard(api);
      await api.setOnline(online: true);

      final trip = await acceptedTrip(api);
      expect(trip.status, PartnerTripStatus.assigned);
      expect(
        trip.commissionPaise,
        (trip.farePaise * 20 / 100).round(),
      );
      expect(trip.earningPaise, trip.farePaise - trip.commissionPaise);
      expect(await api.pendingOffers(), isEmpty);

      final arrived = await api.arrive(trip.bookingId);
      expect(arrived.status, PartnerTripStatus.arrived);

      await expectLater(
        api.verifyOtp(bookingId: trip.bookingId, otp: '0000'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'otp_invalid')),
      );

      final started = await api.verifyOtp(
        bookingId: trip.bookingId,
        otp: trip.devOtpHint!,
      );
      expect(started.status, PartnerTripStatus.inProgress);

      final completed = await api.complete(trip.bookingId);
      expect(completed.status, PartnerTripStatus.completed);
      expect(await api.activeTrip(), isNull);

      final summary = await api.earnings(EarningsRange.today);
      expect(summary.trips, greaterThan(0));
      expect(summary.grossPaise, greaterThanOrEqualTo(trip.farePaise));
      expect(
        summary.commissionPaise,
        (summary.grossPaise * 20 / 100).round(),
      );
      expect(summary.netPaise, summary.grossPaise - summary.commissionPaise);

      final ledger = await api.earningTrips();
      expect(ledger.results.first.bookingId, trip.bookingId);
    });

    test('goods trip requires delivery OTP before completion', () async {
      final api = await registerDriver();
      await onboard(api, category: 'ace', plate: 'KA 51 MN 4477');
      await api.setOnline(online: true);

      final trip = await acceptedTrip(api);
      expect(trip.kind, OfferKind.goods);
      await api.arrive(trip.bookingId);
      await api.verifyOtp(bookingId: trip.bookingId, otp: trip.devOtpHint!);

      await expectLater(
        api.complete(trip.bookingId),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'pod_missing')),
      );
      await expectLater(
        api.verifyDeliveryOtp(bookingId: trip.bookingId, otp: '1111'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'otp_invalid')),
      );
      await api.verifyDeliveryOtp(
        bookingId: trip.bookingId,
        otp: trip.devOtpHint!,
      );
      final done = await api.complete(trip.bookingId);
      expect(done.status, PartnerTripStatus.completed);
    });

    test('decline removes the offer; expired offers cannot be accepted',
        () async {
      final api = await registerDriver();
      await onboard(api);
      await api.setOnline(online: true);
      final offer = api.createSimulatedOffer();
      await api.declineOffer(offer.id);
      expect(await api.pendingOffers(), isEmpty);

      final expiring = await registerDriver(offerExpiry: Duration.zero);
      await onboard(expiring);
      await expiring.setOnline(online: true);
      final stale = expiring.createSimulatedOffer();
      await expectLater(
        expiring.acceptOffer(stale.id),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', 'offer_expired')),
      );
    });

    test('cancel clears the active trip and counts toward cancellation rate',
        () async {
      final api = await registerDriver();
      await onboard(api);
      await api.setOnline(online: true);
      final trip = await acceptedTrip(api);

      await api.cancelTrip(trip.bookingId, reason: 'customer_no_show');
      expect(await api.activeTrip(), isNull);
      final summary = await api.earnings(EarningsRange.month);
      expect(summary.cancellationRate, greaterThan(0));
    });
  });

  group('earnings & fleet', () {
    test('seeded ledger drives ranges; payouts exist', () async {
      final api = await registerDriver();
      final today = await api.earnings(EarningsRange.today);
      expect(today.trips, greaterThan(0));
      expect(today.grossPaise, greaterThan(0));

      final month = await api.earnings(EarningsRange.month);
      expect(month.trips, greaterThan(today.trips));

      final payouts = await api.payouts();
      expect(payouts.results, hasLength(2));
      expect(
        payouts.results.map((p) => p.status),
        containsAll([PayoutStatus.paid, PayoutStatus.pending]),
      );
    });

    test('fleet overview, drivers and vehicle assignment', () async {
      final api = await registerDriver();
      final vehicle = await onboard(api);

      final overview = await api.fleetOverview();
      expect(overview.driversTotal, 3);
      expect(overview.driversActive, 2);
      expect(overview.earningsTodayPaise, greaterThan(0));

      final drivers = await api.fleetDrivers();
      expect(drivers, hasLength(3));

      await api.assignVehicle(
        vehicleId: vehicle.id,
        driverId: drivers.last.id,
      );
      final after = await api.fleetDrivers();
      expect(
        after.firstWhere((d) => d.id == drivers.last.id).vehicleRegistration,
        vehicle.registrationNumber,
      );

      final fleetVehicles = await api.fleetVehicles();
      expect(fleetVehicles.map((v) => v.id), contains(vehicle.id));
    });
  });

  group('driver realtime simulator', () {
    test('emits offers while online, then stops after dispose', () async {
      final api = await registerDriver();
      await onboard(api);
      await api.setOnline(online: true);

      final service = MockDriverRealtimeService(
        api: api,
        offerEvery: const Duration(milliseconds: 40),
      );
      final received = <DriverOffer>[];
      final sub = service.offers().listen(received.add);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(received, isNotEmpty);
      expect(received.first.id, isNotEmpty);

      await sub.cancel();
      service.dispose();
    });
  });
}
