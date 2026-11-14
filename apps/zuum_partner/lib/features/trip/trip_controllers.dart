import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

import '../home/home_controllers.dart';

/// Server-authoritative active trip. Every transition returns the fresh trip
/// so the UI always renders the server's view of the lifecycle.
class TripController extends AsyncNotifier<PartnerTrip?> {
  @override
  Future<PartnerTrip?> build() => ref.watch(partnerApiProvider).activeTrip();

  PartnerApiContract get _api => ref.read(partnerApiProvider);

  PartnerTrip get _current => state.requireValue!;

  void _refreshHome() {
    ref.invalidate(todayEarningsProvider);
    ref.invalidate(acceptanceProvider);
    ref.invalidate(activeTripProvider);
  }

  Future<void> arrive() async {
    state = AsyncData(await _api.arrive(_current.bookingId));
  }

  /// Customer OTP: `arrived → inProgress` (ride start / goods loading done).
  Future<void> start(String otp) async {
    state = AsyncData(
      await _api.verifyOtp(bookingId: _current.bookingId, otp: otp),
    );
  }

  /// Goods only: proves the delivery OTP; `complete()` is then allowed.
  Future<void> verifyDelivery(String otp) async {
    await _api.verifyDeliveryOtp(bookingId: _current.bookingId, otp: otp);
  }

  Future<void> complete() async {
    state = AsyncData(await _api.complete(_current.bookingId));
    _refreshHome();
  }

  Future<void> cancel(String reason) async {
    await _api.cancelTrip(_current.bookingId, reason: reason);
    state = const AsyncData(null);
    _refreshHome();
  }
}

final tripControllerProvider =
    AsyncNotifierProvider<TripController, PartnerTrip?>(TripController.new);
