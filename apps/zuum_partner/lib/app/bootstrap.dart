import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

/// Root widget with environment overrides applied.
///
/// - `mock` (default for local dev + tests): dev-only in-memory token storage
///   and the labeled mock partner API (added in Batch 2).
/// - `dev`/`prod`: secure storage + real API client pointed at
///   `API_BASE_URL` / `WS_BASE_URL`.
ProviderScope zuumPartnerRoot({required Widget child}) {
  return ProviderScope(
    overrides: [
      if (AppEnv.isMock)
        tokenStorageProvider.overrideWithValue(InMemoryTokenStorage()),
    ],
    child: child,
  );
}
