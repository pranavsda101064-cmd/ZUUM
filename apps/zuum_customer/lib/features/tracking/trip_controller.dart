import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

/// Live state of the active trip, fed by [RealtimeService].
@immutable
class TripState {
  const TripState({
    required this.booking,
    this.driver,
    this.vehicle,
    this.otp,
    this.etaSeconds,
    this.location,
    this.finalFarePaise,
  });

  final Booking booking;
  final DriverInfo? driver;
  final VehicleInfo? vehicle;

  /// Trip-start OTP (rides) — shown to share with the driver.
  final String? otp;
  final int? etaSeconds;
  final DriverLocation? location;
  final int? finalFarePaise;

  BookingStatus get status => booking.status;

  TripState copyWith({
    Booking? booking,
    DriverInfo? driver,
    VehicleInfo? vehicle,
    String? otp,
    int? etaSeconds,
    bool clearEta = false,
    DriverLocation? location,
    int? finalFarePaise,
  }) {
    return TripState(
      booking: booking ?? this.booking,
      driver: driver ?? this.driver,
      vehicle: vehicle ?? this.vehicle,
      otp: otp ?? this.otp,
      etaSeconds: clearEta ? null : etaSeconds ?? this.etaSeconds,
      location: location ?? this.location,
      finalFarePaise: finalFarePaise ?? this.finalFarePaise,
    );
  }
}

/// Drives the active trip screen from realtime events. The mock simulator
/// plays the driver; Phase 6 swaps in the WS-backed [RealtimeService].
class TripController extends Notifier<TripState?> {
  StreamSubscription<RealtimeEvent>? _events;
  StreamSubscription<DriverLocation>? _locations;

  RealtimeService get _realtime => ref.read(realtimeServiceProvider);

  @override
  TripState? build() {
    ref.onDispose(_tearDown);
    return null;
  }

  void _tearDown() {
    _events?.cancel();
    _locations?.cancel();
    _events = null;
    _locations = null;
  }

  void start(Booking booking) {
    _tearDown();
    state = TripState(booking: booking);
    _events = _realtime.watchBooking(booking).listen(_onEvent);
    _locations = _realtime
        .watchDriverLocation(booking)
        .listen((l) => state = state?.copyWith(location: l));
  }

  void _onEvent(RealtimeEvent event) {
    final current = state;
    if (current == null || event.bookingId != current.booking.id) return;
    state = current.copyWith(
      booking: current.booking.copyWith(
        status: event.status,
        driver: event.driver,
        vehicle: event.vehicle,
        otp: event.otp,
        finalFarePaise: event.finalFarePaise,
      ),
      driver: event.driver,
      vehicle: event.vehicle,
      otp: event.otp,
      etaSeconds: event.etaSeconds,
      clearEta: event.status == BookingStatus.inProgress ||
          event.status == BookingStatus.completed,
      finalFarePaise: event.finalFarePaise,
    );
  }

  /// Called after payment/rating — releases the simulator session.
  void finish() {
    final booking = state?.booking;
    _tearDown();
    if (booking != null) _realtime.stop(booking.id);
    state = null;
  }

  /// Cancel path — stop simulation immediately.
  void abort() {
    final booking = state?.booking;
    _tearDown();
    if (booking != null) _realtime.stop(booking.id);
    state = null;
  }
}

final tripControllerProvider =
    NotifierProvider<TripController, TripState?>(TripController.new);
