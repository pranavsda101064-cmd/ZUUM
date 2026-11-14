import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';
import '../onboarding/welcome_controller.dart';

/// Partner launch screen — animated carbon-ink brand reveal while the session
/// restores and the partner intro flag hydrates. Routing is owned by the
/// router redirect (splash → welcome / login / KYC / shell).
class PartnerSplash extends ConsumerStatefulWidget {
  const PartnerSplash({super.key});

  @override
  ConsumerState<PartnerSplash> createState() => _PartnerSplashState();
}

class _PartnerSplashState extends ConsumerState<PartnerSplash> {
  /// Kiosk/judge demo: `--dart-define=AUTO_DEMO=true` signs into the seeded
  /// demo partner on launch (mock builds only).
  static const _autoDemo = bool.fromEnvironment('AUTO_DEMO');

  Timer? _timer;

  Future<void> _boot() async {
    final auth = ref.read(partnerAuthProvider.notifier);
    await ref.read(partnerWelcomeProvider.notifier).hydrate();
    await auth.bootstrap();
    if (!mounted) return;
    if (_autoDemo &&
        AppEnv.isMock &&
        ref.read(partnerAuthProvider).status ==
            PartnerAuthStatus.unauthenticated) {
      await auth.enterDemoPartner();
    }
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1200), _boot);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const ZBrandSplash(
      badge: 'PARTNER',
      kannada: 'ಸುಸ್ವಾಗತ',
      tagline: 'Old Bengaluru soul. New Bengaluru movement.',
      footnote: 'Earn on every street in the city · v1.0',
    );
  }
}
