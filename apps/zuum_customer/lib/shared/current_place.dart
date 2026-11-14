import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:zuum_core/core.dart';

/// Foreground-only device fix for the booking flow. Returns `null` when
/// permission/service is unavailable so callers can keep the demo location.
Future<PlaceSuggestion?> currentPlace({String label = 'Current location'}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return PlaceSuggestion(
      name: label,
      address: 'Pinned on the map',
      lat: position.latitude,
      lng: position.longitude,
    );
  } catch (_) {
    return null;
  }
}
