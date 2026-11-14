import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';

/// Partner launch screen — carbon canvas, brand lockup with the lime
/// "PARTNER" flag, brief hold, then session restore. The router redirect
/// decides between login, KYC onboarding and the shell.
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
    return Scaffold(
      backgroundColor: ZColors.dark,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ZBrandMark(scale: 1.4, onDark: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ZColors.highlight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PARTNER',
                  style: ZTypography.overline.copyWith(
                    color: ZColors.dark,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: ZSpacing.xxl),
              Text(
                'Old Bengaluru soul. New Bengaluru movement.',
                style: ZTypography.caption.copyWith(color: ZColors.accent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ZSpacing.xs),
              Text(
                'Earn on every street in the city.',
                style: ZTypography.caption.copyWith(
                  color: ZColors.onDarkSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ZSpacing.z40),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ZColors.highlight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
