import 'dart:async';

import '../api/mock/mock_partner_api.dart';
import '../models/partner_models.dart';

/// Realtime driver feed (`docs/04_realtime_protocol.md`, `driver:{id}` topic).
///
/// Phase 2 swaps the mock implementation for the Channels/WS client behind
/// this same interface — no UI changes.
abstract interface class DriverRealtimeService {
  /// Incoming dispatch offers while the partner is online.
  Stream<DriverOffer> offers();

  void dispose();
}

/// ============================================================
/// DEV-ONLY OFFER SIMULATOR — `ENV=mock` only.
/// Fabricates an incoming offer every [offerEvery] while the partner is
/// online and free. Timing is compressed for the demo.
/// ============================================================
class MockDriverRealtimeService implements DriverRealtimeService {
  MockDriverRealtimeService({
    required this.api,
    this.offerEvery = const Duration(seconds: 25),
  });

  final MockPartnerApi api;
  final Duration offerEvery;

  StreamController<DriverOffer>? _controller;
  Timer? _timer;

  @override
  Stream<DriverOffer> offers() {
    _controller ??= StreamController<DriverOffer>.broadcast();
    _timer ??= Timer.periodic(offerEvery, (_) => _tick());
    return _controller!.stream;
  }

  void _tick() {
    final controller = _controller;
    if (controller == null || controller.isClosed || !controller.hasListener) {
      return;
    }
    if (!api.onlineNow) return;
    try {
      controller.add(api.createSimulatedOffer());
    } catch (_) {
      // Busy with a trip / no active vehicle — the simulator simply waits
      // for the next tick.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }
}

/// Placeholder for non-mock environments until the Phase 2 backend exists.
class NoopDriverRealtimeService implements DriverRealtimeService {
  @override
  Stream<DriverOffer> offers() => const Stream.empty();

  @override
  void dispose() {}
}
