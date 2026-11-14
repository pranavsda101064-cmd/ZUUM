import 'dart:async';
import 'dart:math';

import '../models/models.dart';

/// Realtime trip updates (`docs/04_realtime_protocol.md`).
///
/// Phase 6 swaps [MockRealtimeService] for a Channels/WS-backed
/// implementation of this same interface — no UI changes.
class RealtimeEvent {
  const RealtimeEvent({
    required this.bookingId,
    required this.status,
    this.driver,
    this.vehicle,
    this.otp,
    this.etaSeconds,
    this.finalFarePaise,
  });

  final String bookingId;
  final BookingStatus status;
  final DriverInfo? driver;
  final VehicleInfo? vehicle;
  final String? otp;
  final int? etaSeconds;
  final int? finalFarePaise;
}

class DriverLocation {
  const DriverLocation({
    required this.lat,
    required this.lng,
    this.heading = 0,
    required this.recordedAt,
  });

  final double lat;
  final double lng;
  final double heading;
  final DateTime recordedAt;
}

abstract interface class RealtimeService {
  /// Trip lifecycle events for a booking (ASSIGNED → … → COMPLETED).
  Stream<RealtimeEvent> watchBooking(Booking booking);

  /// Simulated/real driver position while assigned.
  Stream<DriverLocation> watchDriverLocation(Booking booking);

  /// Trip-start or delivery OTP verification (driver-side in production;
  /// the simulator auto-verifies for the customer-only demo).
  Future<void> verifyOtp({required String bookingId, required String otp});

  /// Stop simulating a booking (cancelled).
  void stop(String bookingId);

  void dispose();
}

/// ============================================================
/// DEV-ONLY MOCK DISPATCH SIMULATOR — `ENV=mock` only.
///
/// Plays the driver's side of a trip with compressed, configurable
/// timings so the full lifecycle is demoable in ~30 s. All state
/// transitions mirror the server-authoritative booking state machine.
/// ============================================================
class MockRealtimeService implements RealtimeService {
  MockRealtimeService({
    this.assignAfter = const Duration(seconds: 2),
    this.arriveAfter = const Duration(seconds: 3),
    this.eta = const Duration(seconds: 8),
    this.tripDuration = const Duration(seconds: 15),
    this.onEvent,
  });

  /// Time from booking → driver assigned.
  final Duration assignAfter;

  /// Time from assigned → driver arriving (en route).
  final Duration arriveAfter;

  /// Demo ETA while en route to pickup.
  final Duration eta;

  /// Demo trip duration pickup → drop.
  final Duration tripDuration;

  /// Optional sink so a mock API can mirror events into its stored bookings.
  final void Function(RealtimeEvent event)? onEvent;

  final _sessions = <String, _TripSession>{};
  final _otp = <String, String>{};

  @override
  Stream<RealtimeEvent> watchBooking(Booking booking) {
    final session = _sessions.putIfAbsent(
      booking.id,
      () => _TripSession(booking, this),
    );
    return session.events;
  }

  @override
  Stream<DriverLocation> watchDriverLocation(Booking booking) {
    final session = _sessions.putIfAbsent(
      booking.id,
      () => _TripSession(booking, this),
    );
    return session.locations;
  }

  @override
  Future<void> verifyOtp({required String bookingId, required String otp}) async {
    final expected = _otp[bookingId];
    if (expected == null || expected != otp) {
      throw ArgumentError('Invalid OTP');
    }
    _sessions[bookingId]?.startTrip();
  }

  @override
  void stop(String bookingId) {
    _sessions.remove(bookingId)?.dispose();
    _otp.remove(bookingId);
  }

  String issueOtp(String bookingId) {
    final otp = (1000 + Random().nextInt(9000)).toString();
    _otp[bookingId] = otp;
    return otp;
  }

  void emitToSink(RealtimeEvent event) => onEvent?.call(event);

  @override
  void dispose() {
    for (final s in _sessions.values) {
      s.dispose();
    }
    _sessions.clear();
    _otp.clear();
  }
}

class _TripSession {
  _TripSession(this.booking, this.service) {
    _start();
  }

  final Booking booking;
  final MockRealtimeService service;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _locations = StreamController<DriverLocation>.broadcast();
  final _timers = <Timer>[];
  var _tripStarted = false;

  Stream<RealtimeEvent> get events => _events.stream;
  Stream<DriverLocation> get locations => _locations.stream;

  // Bengaluru demo drivers — dev-only fabricated data.
  static const _drivers = [
    (
      DriverInfo(
        id: 'drv-1',
        name: 'Ravi Kumar',
        phone: '+919800000001',
        ratingAvg: 4.8,
      ),
      VehicleInfo(
        registrationNumber: 'KA 05 AB 1234',
        make: 'Maruti Dzire',
        color: 'White',
        category: 'sedan',
      ),
    ),
    (
      DriverInfo(
        id: 'drv-2',
        name: 'Suresh Babu',
        phone: '+919800000002',
        ratingAvg: 4.6,
      ),
      VehicleInfo(
        registrationNumber: 'KA 03 MK 8890',
        make: 'Bajaj RE Auto',
        color: 'Yellow',
        category: 'auto',
      ),
    ),
    (
      DriverInfo(
        id: 'drv-3',
        name: 'Manjunath H',
        phone: '+919800000003',
        ratingAvg: 4.9,
      ),
      VehicleInfo(
        registrationNumber: 'KA 51 MN 4477',
        make: 'Tata Ace',
        color: 'Blue',
        category: 'ace',
      ),
    ),
  ];

  void _start() {
    _emit(booking.status);
    _schedule(service.assignAfter, _assign);
  }

  void _schedule(Duration d, void Function() fn) {
    _timers.add(Timer(d, fn));
  }

  void _assign() {
    if (_events.isClosed) return;
    final (driver, vehicle) =
        _drivers[DateTime.now().millisecondsSinceEpoch % _drivers.length];
    // Trip-start OTP is ride-only; goods keep their delivery OTP.
    final otp = booking.type == BookingType.ride
        ? service.issueOtp(booking.id)
        : null;
    _emit(
      BookingStatus.assigned,
      driver: driver,
      vehicle: vehicle,
      otp: otp,
    );
    _schedule(service.arriveAfter, _enRoute);
  }

  void _enRoute() {
    if (_events.isClosed) return;
    _emit(BookingStatus.driverArriving, etaSeconds: service.eta.inSeconds);
    _simulateApproach();
    // The "driver" confirms the OTP shortly after arrival.
    _schedule(service.eta, startTrip);
  }

  void _simulateApproach() {
    // A few location pings converging on the pickup point.
    const pings = 4;
    final pickup = _pickupOf(booking);
    for (var i = 1; i <= pings; i++) {
      _schedule(
        Duration(milliseconds: service.eta.inMilliseconds * i ~/ (pings + 1)),
        () {
          if (_locations.isClosed) return;
          final t = i / (pings + 1);
          final startLat = pickup.lat + 0.02;
          final startLng = pickup.lng - 0.015;
          _locations.add(
            DriverLocation(
              lat: startLat + (pickup.lat - startLat) * t,
              lng: startLng + (pickup.lng - startLng) * t,
              heading: 135,
              recordedAt: DateTime.now().toUtc(),
            ),
          );
        },
      );
    }
  }

  void startTrip() {
    if (_tripStarted || _events.isClosed) return;
    _tripStarted = true;
    _emit(BookingStatus.inProgress);
    _simulateTrip();
    _schedule(service.tripDuration, _complete);
  }

  void _simulateTrip() {
    const pings = 6;
    final from = _pickupOf(booking);
    final to = _dropOf(booking);
    for (var i = 1; i <= pings; i++) {
      _schedule(
        Duration(milliseconds: service.tripDuration.inMilliseconds * i ~/ (pings + 1)),
        () {
          if (_locations.isClosed) return;
          final t = i / (pings + 1);
          _locations.add(
            DriverLocation(
              lat: from.lat + (to.lat - from.lat) * t,
              lng: from.lng + (to.lng - from.lng) * t,
              heading: 90,
              recordedAt: DateTime.now().toUtc(),
            ),
          );
        },
      );
    }
  }

  void _complete() {
    if (_events.isClosed) return;
    _emit(
      BookingStatus.completed,
      finalFarePaise: booking.quotedFarePaise,
    );
  }

  void _emit(
    BookingStatus status, {
    DriverInfo? driver,
    VehicleInfo? vehicle,
    String? otp,
    int? etaSeconds,
    int? finalFarePaise,
  }) {
    final event = RealtimeEvent(
      bookingId: booking.id,
      status: status,
      driver: driver,
      vehicle: vehicle,
      otp: otp,
      etaSeconds: etaSeconds,
      finalFarePaise: finalFarePaise,
    );
    _events.add(event);
    service.emitToSink(event);
  }

  static LocationPoint _pickupOf(Booking b) => LocationPoint(
        lat: b.pickupLat ?? 12.9352,
        lng: b.pickupLng ?? 77.6245,
        address: b.pickupAddress,
      );

  static LocationPoint _dropOf(Booking b) => LocationPoint(
        lat: b.dropLat ?? 12.9719,
        lng: b.dropLng ?? 77.6412,
        address: b.dropAddress,
      );

  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _events.close();
    _locations.close();
  }
}
