import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

enum PartnerAuthStatus { unknown, unauthenticated, authenticated }

class PartnerAuthState {
  const PartnerAuthState({
    this.status = PartnerAuthStatus.unknown,
    this.user,
    this.profile,
    this.error,
    this.busy = false,
  });

  final PartnerAuthStatus status;
  final ZUser? user;
  final PartnerProfile? profile;
  final String? error;
  final bool busy;

  bool get isApproved => profile?.isApproved ?? false;
  KycStatus? get kycStatus => profile?.kycStatus;

  PartnerAuthState copyWith({
    PartnerAuthStatus? status,
    ZUser? user,
    PartnerProfile? profile,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return PartnerAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      profile: profile ?? this.profile,
      error: clearError ? null : error ?? this.error,
      busy: busy ?? this.busy,
    );
  }
}

class PartnerAuthController extends Notifier<PartnerAuthState> {
  @override
  PartnerAuthState build() => const PartnerAuthState();

  PartnerApiContract get _api => ref.read(partnerApiProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  /// Restore a stored session and load the partner profile.
  Future<void> bootstrap() async {
    try {
      final stored = await _storage.readSession();
      if (stored == null) {
        state = const PartnerAuthState(status: PartnerAuthStatus.unauthenticated);
        return;
      }
      final refreshed = await _api.refresh(stored.refreshToken);
      await _storage.saveSession(refreshed);
      final profile = await _api.profile();
      state = PartnerAuthState(
        status: PartnerAuthStatus.authenticated,
        user: refreshed.user,
        profile: profile,
      );
    } catch (_) {
      await _storage.clear();
      state = const PartnerAuthState(status: PartnerAuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String email, required String password}) =>
      _authenticate(() => _api.login(email: email, password: password));

  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) =>
      _authenticate(
        () => _api.register(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        ),
      );

  /// DEV-ONLY (mock builds): seeds/signs into a fully-approved demo partner
  /// so judges and testers can reach the dashboard in one tap. The mock user
  /// lives in memory only; a fresh process starts from the login screen.
  Future<bool> enterDemoPartner() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final api = _api;
      const email = 'demo@zuum.in';
      const password = 'demo1234';
      Session session;
      try {
        session = await api.login(email: email, password: password);
      } on ApiException {
        await api.register(
          email: email,
          password: password,
          firstName: 'Demo',
          lastName: 'Partner',
          phone: '9845000000',
        );
        for (final type in const [
          KycDocType.licence,
          KycDocType.rc,
          KycDocType.insurance,
        ]) {
          await api.uploadDocument(
            type: type,
            filePath: 'demo://demo-${type.name}.jpg',
          );
        }
        await api.createVehicle(
          categoryCode: 'auto',
          registrationNumber: 'KA 01 DM 0001',
          make: 'Bajaj',
          model: 'RE Auto',
          color: 'Yellow',
        );
        await api.submitKyc();
        session = await api.login(email: email, password: password);
      }
      await _storage.saveSession(session);
      final profile = await api.profile();
      state = PartnerAuthState(
        status: PartnerAuthStatus.authenticated,
        user: session.user,
        profile: profile,
      );
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

  Future<bool> _authenticate(Future<Session> Function() action) async {    state = state.copyWith(busy: true, clearError: true);
    try {
      final session = await action();
      await _storage.saveSession(session);
      final profile = await _api.profile();
      state = PartnerAuthState(
        status: PartnerAuthStatus.authenticated,
        user: session.user,
        profile: profile,
      );
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

  /// Re-fetch profile (KYC review polling, availability changes).
  Future<void> refreshProfile() async {
    if (state.status != PartnerAuthStatus.authenticated) return;
    try {
      final profile = await _api.profile();
      state = state.copyWith(profile: profile);
    } catch (_) {
      // Keep the last known profile; the UI surfaces stale data honestly.
    }
  }

  Future<void> signOut() async {
    try {
      final stored = await _storage.readSession();
      if (stored != null) {
        await _api.logout(stored.refreshToken);
      }
    } catch (_) {
      // Local session is cleared regardless.
    }
    await _storage.clear();
    state = const PartnerAuthState(status: PartnerAuthStatus.unauthenticated);
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(clearError: true);
  }

  String _message(ApiException e) {
    if (e.isNetwork) return 'No internet connection. Check your network.';
    if (e.isRateLimited) return 'Too many attempts. Please wait a moment.';
    return e.message;
  }
}

final partnerAuthProvider =
    NotifierProvider<PartnerAuthController, PartnerAuthState>(
  PartnerAuthController.new,
);

/// Partner profile (invalidated after KYC/document/vehicle mutations).
final partnerProfileProvider = FutureProvider<PartnerProfile>(
  (ref) => ref.watch(partnerApiProvider).profile(),
);

/// Vehicles for the current partner.
final partnerVehiclesProvider = FutureProvider<List<PartnerVehicle>>(
  (ref) => ref.watch(partnerApiProvider).vehicles(),
);

/// KYC documents for the current partner.
final partnerDocumentsProvider = FutureProvider<List<KycDocumentInfo>>(
  (ref) => ref.watch(partnerApiProvider).documents(),
);
