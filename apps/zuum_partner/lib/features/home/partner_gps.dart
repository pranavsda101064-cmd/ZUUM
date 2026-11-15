import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zuum_core/core.dart';

/// Foreground-only GPS for the partner app.
///
/// Requests while-in-use permission, exposes a position stream and fails
/// quietly when location is unavailable.
class PartnerGps {
  static bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  static const _mockPoint = LocationPoint(lat: 12.9352, lng: 77.6245);

  Future<bool> ensurePermission() async {
    if (_isTest) return false;
    if (AppEnv.isMock) return true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<LocationPoint?> current() async {
    if (_isTest) return null;
    if (AppEnv.isMock) return _mockPoint;
    if (!await ensurePermission()) return null;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return _toPoint(position);
    } catch (_) {
      return null;
    }
  }

  Stream<LocationPoint> stream() async* {
    if (_isTest) return;
    if (AppEnv.isMock) {
      yield _mockPoint;
      return;
    }
    if (!await ensurePermission()) return;
    yield* Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).map(_toPoint).handleError((_) {});
  }

  static LocationPoint _toPoint(Position position) => LocationPoint(
        lat: position.latitude,
        lng: position.longitude,
      );
}

final partnerGpsProvider = Provider<PartnerGps>((ref) => PartnerGps());
