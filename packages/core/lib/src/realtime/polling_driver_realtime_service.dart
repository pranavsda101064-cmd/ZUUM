import 'dart:async';

import '../api/partner_api_contract.dart';
import 'driver_realtime_service.dart';
import '../models/partner_models.dart';

/// Polling-based driver offer feed.
///
/// Robust on Render's free tier (cold starts/WS drops): every few seconds it
/// asks the REST endpoint for pending offers and emits only new ones. A WS
/// implementation can be layered on later without changing the UI contract.
class PollingDriverRealtimeService implements DriverRealtimeService {
  PollingDriverRealtimeService({
    required this.api,
    this.pollEvery = const Duration(seconds: 5),
  });

  final PartnerApiContract api;
  final Duration pollEvery;

  StreamController<DriverOffer>? _controller;
  Timer? _timer;
  final _seen = <String>{};
  final _queue = <String>[];

  @override
  Stream<DriverOffer> offers() {
    _controller ??= StreamController<DriverOffer>.broadcast();
    _timer ??= Timer.periodic(pollEvery, (_) => _poll());
    return _controller!.stream;
  }

  Future<void> _poll() async {
    final controller = _controller;
    if (controller == null || controller.isClosed || !controller.hasListener) {
      return;
    }
    try {
      final offers = await api.pendingOffers();
      for (final offer in offers) {
        if (offer.isExpired) continue;
        if (!_seen.add(offer.id)) continue;
        _queue.add(offer.id);
        controller.add(offer);
      }
      while (_queue.length > 200) {
        _seen.remove(_queue.removeAt(0));
      }
    } catch (_) {
      // Offline / cold start: retry on the next tick.
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
