import '../api/api_contract.dart';
import 'place_search.dart';

/// OSM places through the Django proxy (`/places/search`), with auth + cache.
class BackendPlaceSearch implements PlaceSearchService {
  BackendPlaceSearch({required this.api});

  final ApiContract api;

  @override
  Future<List<PlaceSuggestion>> search(
    String query, {
    required double proximityLat,
    required double proximityLng,
    int limit = 8,
  }) =>
      api.searchPlaces(
        query,
        lat: proximityLat,
        lng: proximityLng,
        limit: limit,
      );
}
