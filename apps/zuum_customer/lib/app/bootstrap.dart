import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

/// Root widget with environment overrides applied.
///
/// Riverpod 3's `Override` type is not publicly nameable, so overrides are
/// provided as inline list literals and inferred from `ProviderScope`.
///
/// - `mock` (default for local dev): dev-only in-memory token storage, the
///   labeled MockApiAdapter, and the mock dispatch simulator wired to keep
///   stored bookings in sync with trip events.
/// - `dev`/`prod`: secure storage + real API client pointed at
///   `API_BASE_URL` / `WS_BASE_URL`.
ProviderScope zuumRoot({required Widget child}) {
  if (AppEnv.isMock) {
    final mockApi = MockApiAdapter();
    return ProviderScope(
      overrides: [
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
        apiContractProvider.overrideWithValue(mockApi),
        realtimeServiceProvider.overrideWithValue(
          MockRealtimeService(onEvent: mockApi.applyRealtimeEvent),
        ),
        paymentGatewayProvider.overrideWithValue(MockPaymentGateway()),
      ],
      child: child,
    );
  }
  return ProviderScope(child: child);
}
