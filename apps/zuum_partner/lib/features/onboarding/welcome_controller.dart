import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';

/// Persisted "seen the partner intro" flag. Mirrors the customer app's
/// onboarding gate but lives in partner storage (separate app package).
class PartnerWelcome extends Notifier<bool> {
  @override
  bool build() => false;

  Future<void> hydrate() async {
    final seen = await ref.read(prefsStoreProvider).onboarded;
    if (seen != state) state = seen;
  }

  Future<void> finish() async {
    await ref.read(prefsStoreProvider).setOnboarded(true);
    state = true;
  }
}

final partnerWelcomeProvider =
    NotifierProvider<PartnerWelcome, bool>(PartnerWelcome.new);
