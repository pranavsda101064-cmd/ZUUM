import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.error,
    this.busy = false,
  });

  final AuthStatus status;
  final ZUser? user;
  final String? error;
  final bool busy;

  AuthState copyWith({
    AuthStatus? status,
    ZUser? user,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : error ?? this.error,
      busy: busy ?? this.busy,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  AuthRepository get _repo => AuthRepository(
        api: ref.read(apiContractProvider),
        storage: ref.read(tokenStorageProvider),
      );

  /// Restore a stored session on app start. Never throws — failures land the
  /// user on the login screen.
  Future<void> bootstrap() async {
    try {
      final session = await _repo.restoreSession();
      state = session == null
          ? const AuthState(status: AuthStatus.unauthenticated)
          : AuthState(status: AuthStatus.authenticated, user: session.user);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _repo.login(email: email, password: password);
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await _repo.register(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );
      state = AuthState(status: AuthStatus.authenticated, user: session.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
      return false;
    } catch (_) {
      state = state.copyWith(
        busy: false,
        error: 'Something went wrong. Please try again.',
      );
      return false;
    }
  }

  Future<void> forgotPassword(String email) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _repo.forgotPassword(email);
      state = state.copyWith(busy: false, clearError: true);
    } on ApiException catch (e) {
      state = state.copyWith(busy: false, error: _message(e));
    }
  }

  Future<void> signOut() async {
    try {
      await _repo.signOut();
    } catch (_) {
      // Local session is cleared regardless.
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Reflect a profile update in the session state.
  void updateUser(ZUser user) {
    state = state.copyWith(user: user);
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(clearError: true);
    }
  }

  String _message(ApiException e) {
    if (e.isNetwork) return 'No internet connection. Check your network.';
    if (e.isRateLimited) return 'Too many attempts. Please wait a moment.';
    return e.message;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
