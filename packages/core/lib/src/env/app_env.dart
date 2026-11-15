import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_contract.dart';
import '../api/mock/mock_api_adapter.dart';
import '../api/api_partner_client.dart';
import '../api/mock/mock_partner_api.dart';
import '../api/partner_api_contract.dart';
import '../payments/payment_gateway.dart';
import '../places/place_search.dart';
import '../places/backend_place_search.dart';
import '../realtime/driver_realtime_service.dart';
import '../realtime/polling_driver_realtime_service.dart';
import '../realtime/realtime_service.dart';
import '../realtime/polling_customer_realtime_service.dart';
import '../storage/prefs_store.dart';
import '../storage/token_storage.dart';

/// Build-time environment. `ENV=mock|dev|prod` via `--dart-define`.
enum AppEnvironment { mock, dev, prod }

abstract final class AppEnv {
  static const String _raw = String.fromEnvironment('ENV', defaultValue: 'mock');
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.zuum.in/api/v1',
  );
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://api.zuum.in/ws',
  );
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue: '',
  );

  static AppEnvironment get environment => switch (_raw) {
        'dev' => AppEnvironment.dev,
        'prod' => AppEnvironment.prod,
        _ => AppEnvironment.mock,
      };

  static bool get isMock => environment == AppEnvironment.mock;
  static bool get isProd => environment == AppEnvironment.prod;
}

/// Token storage provider — overridden at bootstrap per environment.
final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());

/// Local prefs (onboarding flag etc.).
final prefsStoreProvider = Provider<PrefsStore>((ref) => SharedPrefsStore());

/// The API implementation for the current environment.
///
/// [MockApiAdapter] is DEV-ONLY and is only reachable when `ENV=mock`
/// (the default for local development and widget tests).
final apiContractProvider = Provider<ApiContract>((ref) {
  if (AppEnv.isMock) return MockApiAdapter();
  return ApiClient(baseUrl: AppEnv.apiBaseUrl, tokenStorage: ref.watch(tokenStorageProvider));
});

/// Place search - Mapbox when a token is configured, Nominatim (OSM, free)
/// otherwise. Widget tests override with the deterministic MockPlaceSearch.
final placeSearchProvider = Provider<PlaceSearchService>((ref) {
  if (!AppEnv.isMock) {
    return BackendPlaceSearch(api: ref.watch(apiContractProvider));
  }
  if (AppEnv.mapboxAccessToken.isNotEmpty) return MapboxPlaceSearch();
  return NominatimPlaceSearch();
});

/// Realtime trip feed. Mock dispatch simulator until the WS backend (Phase 6).
final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  if (AppEnv.isMock) return MockRealtimeService();
  final service = PollingCustomerRealtimeService(
    api: ref.watch(apiContractProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Payment gateway seam. Mock until Razorpay keys are configured.
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  return MockPaymentGateway();
});
/// Partner API surface (`docs/06_partner_api.md`).
/// `MockPartnerApi` is DEV-ONLY and reachable only when `ENV=mock`.
final partnerApiProvider = Provider<PartnerApiContract>((ref) {
  if (AppEnv.isMock) return MockPartnerApi();
  return ApiPartnerClient(
    baseUrl: AppEnv.apiBaseUrl,
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

/// Driver offer feed — mock simulator until the WS backend (Phase 6).
final driverRealtimeProvider = Provider<DriverRealtimeService>((ref) {
  final api = ref.watch(partnerApiProvider);
  if (api is MockPartnerApi) {
    final service = MockDriverRealtimeService(api: api);
    ref.onDispose(service.dispose);
    return service;
  }
  final service = PollingDriverRealtimeService(api: api);
  ref.onDispose(service.dispose);
  return service;
});