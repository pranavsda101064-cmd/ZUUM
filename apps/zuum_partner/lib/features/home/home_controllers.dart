import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

/// Online/offline availability, server-authoritative via `setOnline`.
class OnlineStatus extends Notifier<bool> {
  @override
  bool build() => false;

  PartnerApiContract get _api => ref.read(partnerApiProvider);

  /// Restore the server state on first home build (e.g. app resume).
  Future<void> hydrate() async {
    try {
      final online = await _api.isOnline();
      if (online != state) state = online;
    } catch (_) {
      // Keep local state; the toggle surfaces real errors.
    }
  }

  /// Throws [ApiException] (`not_approved`, `vehicle_inactive`) — the caller
  /// shows the message.
  Future<void> setOnline(bool online) async {
    await _api.setOnline(online: online);
    state = online;
    ref.invalidate(todayEarningsProvider);
    ref.invalidate(activeTripProvider);
  }
}

final onlineStatusProvider =
    NotifierProvider<OnlineStatus, bool>(OnlineStatus.new);

/// Today's earnings snapshot for the home stats.
final todayEarningsProvider = FutureProvider<EarningsSummary>(
  (ref) => ref.watch(partnerApiProvider).earnings(EarningsRange.today),
);

/// The currently assigned trip, if any (survives app restart via the API).
final activeTripProvider = FutureProvider<PartnerTrip?>(
  (ref) => ref.watch(partnerApiProvider).activeTrip(),
);

/// Acceptance rate over the last 30 days (for the home stat card).
final acceptanceProvider = FutureProvider<double>(
  (ref) => ref
      .watch(partnerApiProvider)
      .earnings(EarningsRange.month)
      .then((e) => e.acceptanceRate),
);
