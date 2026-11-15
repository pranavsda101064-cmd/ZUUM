import 'dart:async';

import '../api/api_contract.dart';
import '../models/models.dart';
import 'realtime_service.dart';

/// REST polling fallback for live tracking (works through Render cold starts).
class PollingCustomerRealtimeService implements RealtimeService {
  PollingCustomerRealtimeService({
    required this.api,
    this.pollEvery = const Duration(seconds: 4),
  });

  final ApiContract api;
  final Duration pollEvery;

  final _events = <String, StreamController<RealtimeEvent>>{};
  final _locations = <String, StreamController<DriverLocation>>{};
  final _eventTimers = <String, Timer>{};
  final _locationTimers = <String, Timer>{};
  final _lastStatus = <String, BookingStatus>{};
  final _lastLocation = <String, DriverLocation>{};

  @override
  Stream<RealtimeEvent> watchBooking(Booking booking) {
    final controller = _events.putIfAbsent(
      booking.id,
      () => StreamController<RealtimeEvent>.broadcast(),
    );
    _eventTimers.putIfAbsent(
      booking.id,
      () => Timer.periodic(pollEvery, (_) => _pollBooking(booking.id)),
    );
    _pollBooking(booking.id);
    return controller.stream;
  }

  Future<void> _pollBooking(String bookingId) async {
    try {
      final booking = await api.booking(bookingId);
      if (_lastStatus[bookingId] == booking.status) return;
      _lastStatus[bookingId] = booking.status;
      _events[bookingId]?.add(
        RealtimeEvent(
          bookingId: bookingId,
          status: booking.status,
          driver: booking.driver,
          vehicle: booking.vehicle,
          otp: booking.otp,
          finalFarePaise: booking.finalFarePaise,
        ),
      );
      if (booking.status == BookingStatus.completed ||
          booking.status == BookingStatus.cancelled ||
          booking.status == BookingStatus.failed) {
        _eventTimers.remove(bookingId)?.cancel();
      }
    } catch (_) {
      // Cold start/offline: retry on the next tick.
    }
  }

  @override
  Stream<DriverLocation> watchDriverLocation(Booking booking) {
    final controller = _locations.putIfAbsent(
      booking.id,
      () => StreamController<DriverLocation>.broadcast(),
    );
    _locationTimers.putIfAbsent(
      booking.id,
      () => Timer.periodic(pollEvery, (_) => _pollLocation(booking.id)),
    );
    _pollLocation(booking.id);
    return controller.stream;
  }

  Future<void> _pollLocation(String bookingId) async {
    try {
      final location = await api.bookingLocation(bookingId);
      if (location == null) return;
      final last = _lastLocation[bookingId];
      if (last != null &&
          last.lat == location.lat &&
          last.lng == location.lng) {
        return;
      }
      _lastLocation[bookingId] = location;
      _locations[bookingId]?.add(location);
    } catch (_) {
      // No driver yet / transient error.
    }
  }

  @override
  Future<void> verifyOtp({required String bookingId, required String otp}) =>
      api.verifyOtp(bookingId: bookingId, otp: otp);

  @override
  void stop(String bookingId) {
    _eventTimers.remove(bookingId)?.cancel();
    _locationTimers.remove(bookingId)?.cancel();
    _events.remove(bookingId)?.close();
    _locations.remove(bookingId)?.close();
  }

  @override
  void dispose() {
    for (final bookingId in {
      ..._eventTimers.keys,
      ..._locationTimers.keys,
      ..._events.keys,
      ..._locations.keys,
    }) {
      stop(bookingId);
    }
  }
}
