import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';
import '../models/user.dart';

abstract interface class TokenStorage {
  Future<void> saveSession(Session session);
  Future<Session?> readSession();
  Future<void> clear();
}

/// Real storage backed by Android Keystore / iOS Keychain.
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage()
      : _storage = const FlutterSecureStorage(aOptions: AndroidOptions());

  static const _kAccess = 'zuum.access';
  static const _kRefresh = 'zuum.refresh';
  static const _kUser = 'zuum.user';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession(Session session) async {
    await _storage.write(key: _kAccess, value: session.accessToken);
    await _storage.write(key: _kRefresh, value: session.refreshToken);
    await _storage.write(key: _kUser, value: jsonEncode(session.user.toJson()));
  }

  @override
  Future<Session?> readSession() async {
    final access = await _storage.read(key: _kAccess);
    final refresh = await _storage.read(key: _kRefresh);
    final userJson = await _storage.read(key: _kUser);
    if (access == null || refresh == null || userJson == null) return null;
    try {
      return Session(
        accessToken: access,
        refreshToken: refresh,
        user: ZUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}

/// In-memory storage for `ENV=mock` and widget tests (no platform channels).
class InMemoryTokenStorage implements TokenStorage {
  Session? _session;

  @override
  Future<void> saveSession(Session session) async => _session = session;

  @override
  Future<Session?> readSession() async => _session;

  @override
  Future<void> clear() async => _session = null;
}
