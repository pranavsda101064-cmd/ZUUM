import 'package:dio/dio.dart';

import '../env/app_env.dart';

/// A place suggestion from geocoding.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  final String name;
  final String address;
  final double lat;
  final double lng;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) => PlaceSuggestion(
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'address': address, 'lat': lat, 'lng': lng};
}

/// Place search abstraction. Real builds use Mapbox or Nominatim;
/// tests use the curated [MockPlaceSearch].
abstract interface class PlaceSearchService {
  Future<List<PlaceSuggestion>> search(
    String query, {
    required double proximityLat,
    required double proximityLng,
    int limit = 8,
  });
}

/// Real implementation - Mapbox Geocoding API v5.
class MapboxPlaceSearch implements PlaceSearchService {
  MapboxPlaceSearch({String? accessToken, Dio? dio})
      : _token = accessToken ?? AppEnv.mapboxAccessToken,
        _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));

  final String _token;
  final Dio _dio;

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required double proximityLat,
    required double proximityLng,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _token.isEmpty) return const [];
    try {
      final res = await _dio.get<dynamic>(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/'
        '${Uri.encodeComponent(trimmed)}.json',
        queryParameters: {
          'access_token': _token,
          'proximity': '$proximityLng,$proximityLat',
          'limit': limit,
          'country': 'in',
          'types': 'place,locality,address,poi',
        },
      );
      final features = (res.data is Map<String, dynamic>
              ? (res.data as Map<String, dynamic>)['features'] as List<dynamic>? ??
                  const []
              : const [])
          .cast<Map<String, dynamic>>();
      return [
        for (final f in features)
          PlaceSuggestion(
            name: (f['text'] as String?) ?? (f['place_name'] as String? ?? ''),
            address: (f['place_name'] as String?) ?? '',
            lat: ((f['center'] as List<dynamic>?)?[1] as num?)?.toDouble() ??
                proximityLat,
            lng: ((f['center'] as List<dynamic>?)?[0] as num?)?.toDouble() ??
                proximityLng,
          ),
      ];
    } on DioException {
      // Search is best-effort - empty list keeps the UI usable offline.
      return const [];
    }
  }
}

/// Real implementation - OpenStreetMap Nominatim geocoding. Free, no API key.
/// Respects the OSM usage policy (identifying User-Agent; the search screen
/// debounces input to keep request rates low).
class NominatimPlaceSearch implements PlaceSearchService {
  NominatimPlaceSearch({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                headers: {'User-Agent': 'zuum-customer/0.1 (dev)'},
              ),
            );

  final Dio _dio;

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required double proximityLat,
    required double proximityLng,
    int limit = 8,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final res = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': trimmed,
          'format': 'json',
          'limit': limit,
          'addressdetails': 0,
          // Bias toward the user's area but allow global hits.
          'viewbox':
              '${proximityLng - 0.6},${proximityLat + 0.6},${proximityLng + 0.6},${proximityLat - 0.6}',
          'bounded': 0,
        },
      );
      final list = res.data is List
          ? (res.data as List).cast<Map<String, dynamic>>()
          : const <Map<String, dynamic>>[];
      return [
        for (final r in list)
          PlaceSuggestion(
            name: _shortName(
              r['name'] as String? ?? '',
              r['display_name'] as String? ?? '',
            ),
            address: r['display_name'] as String? ?? '',
            lat: double.tryParse(r['lat'] as String? ?? '') ?? proximityLat,
            lng: double.tryParse(r['lon'] as String? ?? '') ?? proximityLng,
          ),
      ];
    } on DioException {
      // Best-effort - the curated fallback keeps the UI usable.
      return const [];
    }
  }

  static String _shortName(String name, String displayName) {
    if (name.isNotEmpty) return name;
    final first = displayName.split(',').first.trim();
    return first.isEmpty ? displayName : first;
  }
}

// ============================================================
// DEV-ONLY MOCK PLACE SEARCH - `ENV=mock` and widget tests only.
// Curated Bengaluru landmarks. Fabricated development data.
// ============================================================
class MockPlaceSearch implements PlaceSearchService {
  MockPlaceSearch({this.latency = const Duration(milliseconds: 250)});

  final Duration latency;

  static const _places = <PlaceSuggestion>[
    PlaceSuggestion(
      name: 'MG Road',
      address: 'Mahatma Gandhi Road, Bengaluru',
      lat: 12.9756,
      lng: 77.6068,
    ),
    PlaceSuggestion(
      name: 'Cubbon Park',
      address: 'Kasturba Road, Bengaluru',
      lat: 12.9763,
      lng: 77.5929,
    ),
    PlaceSuggestion(
      name: 'Lalbagh Botanical Garden',
      address: 'Mavalli, Bengaluru',
      lat: 12.9507,
      lng: 77.5848,
    ),
    PlaceSuggestion(
      name: 'Vidhana Soudha',
      address: 'Dr B R Ambedkar Veedhi, Bengaluru',
      lat: 12.9796,
      lng: 77.5907,
    ),
    PlaceSuggestion(
      name: 'Kempegowda International Airport',
      address: 'Devanahalli, Bengaluru',
      lat: 13.1986,
      lng: 77.7066,
    ),
    PlaceSuggestion(
      name: 'Whitefield',
      address: 'Whitefield Main Road, Bengaluru',
      lat: 12.9698,
      lng: 77.7500,
    ),
    PlaceSuggestion(
      name: 'Electronic City',
      address: 'Electronic City Phase 1, Bengaluru',
      lat: 12.8452,
      lng: 77.6602,
    ),
    PlaceSuggestion(
      name: 'Indiranagar',
      address: '100 Feet Road, Indiranagar, Bengaluru',
      lat: 12.9784,
      lng: 77.6408,
    ),
    PlaceSuggestion(
      name: 'Koramangala',
      address: '80 Feet Road, Koramangala, Bengaluru',
      lat: 12.9352,
      lng: 77.6245,
    ),
    PlaceSuggestion(
      name: 'HSR Layout',
      address: 'Sector 2, HSR Layout, Bengaluru',
      lat: 12.9116,
      lng: 77.6389,
    ),
    PlaceSuggestion(
      name: 'Jayanagar',
      address: '4th Block, Jayanagar, Bengaluru',
      lat: 12.9250,
      lng: 77.5938,
    ),
    PlaceSuggestion(
      name: 'Malleshwaram',
      address: 'Sampige Road, Malleshwaram, Bengaluru',
      lat: 13.0055,
      lng: 77.5692,
    ),
    PlaceSuggestion(
      name: 'Basavanagudi',
      address: 'Bull Temple Road, Basavanagudi, Bengaluru',
      lat: 12.9422,
      lng: 77.5738,
    ),
    PlaceSuggestion(
      name: 'Marathahalli',
      address: 'Outer Ring Road, Marathahalli, Bengaluru',
      lat: 12.9592,
      lng: 77.6974,
    ),
    PlaceSuggestion(
      name: 'Banashankari',
      address: 'Banashankari 2nd Stage, Bengaluru',
      lat: 12.9250,
      lng: 77.5468,
    ),
    PlaceSuggestion(
      name: 'Hebbal',
      address: 'Hebbal Flyover, Bengaluru',
      lat: 13.0358,
      lng: 77.5970,
    ),
    PlaceSuggestion(
      name: 'KSR Bengaluru City Railway Station',
      address: 'Majestic, Bengaluru',
      lat: 12.9762,
      lng: 77.5677,
    ),
    PlaceSuggestion(
      name: 'Bengaluru Cantonment Railway Station',
      address: 'Cantonment, Bengaluru',
      lat: 12.9896,
      lng: 77.5986,
    ),
    PlaceSuggestion(
      name: 'Phoenix Marketcity',
      address: 'Whitefield Main Road, Bengaluru',
      lat: 12.9756,
      lng: 77.6676,
    ),
    PlaceSuggestion(
      name: 'UB City',
      address: 'Vittal Mallya Road, Bengaluru',
      lat: 12.9721,
      lng: 77.5946,
    ),
    PlaceSuggestion(
      name: 'Manyata Tech Park',
      address: 'Nagavara, Bengaluru',
      lat: 13.0483,
      lng: 77.6200,
    ),
    PlaceSuggestion(
      name: 'Forum Mall',
      address: 'Hosur Road, Koramangala, Bengaluru',
      lat: 12.9346,
      lng: 77.6110,
    ),
  ];

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required double proximityLat,
    required double proximityLng,
    int limit = 8,
  }) async {
    if (latency != Duration.zero) {
      await Future<void>.delayed(latency);
    }
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _places.take(limit).toList();
    return _places
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.address.toLowerCase().contains(q))
        .take(limit)
        .toList();
  }
}
