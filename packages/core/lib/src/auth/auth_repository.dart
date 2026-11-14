import '../api/api_contract.dart';
import '../models/session.dart';
import '../models/user.dart';
import '../storage/token_storage.dart';

/// Auth use-cases: keeps [TokenStorage] in sync with [ApiContract].
class AuthRepository {
  AuthRepository({required ApiContract api, required TokenStorage storage})
      : _api = api,
        _storage = storage;

  final ApiContract _api;
  final TokenStorage _storage;

  Future<Session> login({required String email, required String password}) async {
    final session = await _api.login(email: email, password: password);
    await _storage.saveSession(session);
    return session;
  }

  Future<Session> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final session = await _api.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
    await _storage.saveSession(session);
    return session;
  }

  /// Restore a previously stored session, refreshing it if needed.
  /// Returns null when there is no usable session.
  Future<Session?> restoreSession() async {
    final stored = await _storage.readSession();
    if (stored == null) return null;
    try {
      final refreshed = await _api.refresh(stored.refreshToken);
      await _storage.saveSession(refreshed);
      return refreshed;
    } catch (_) {
      // Try using the access token as-is (still valid).
      try {
        await _api.me();
        return stored;
      } catch (_) {
        await _storage.clear();
        return null;
      }
    }
  }

  Future<ZUser> me() => _api.me();

  Future<void> signOut() async {
    final stored = await _storage.readSession();
    if (stored != null) {
      try {
        await _api.logout(stored.refreshToken);
      } catch (_) {
        // Best-effort; local clear below is what matters.
      }
    }
    await _storage.clear();
  }

  Future<void> forgotPassword(String email) => _api.forgotPassword(email);

  Future<void> resetPassword({required String token, required String password}) =>
      _api.resetPassword(token: token, password: password);
}
