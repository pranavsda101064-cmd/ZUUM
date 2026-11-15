import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import 'partner_theme.dart';
import 'router.dart';

class PartnerApp extends ConsumerWidget {
  const PartnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(partnerRouterProvider);
    return MaterialApp.router(
      title: 'Zuum Partner',
      debugShowCheckedModeBanner: false,
      theme: PartnerTheme.light(),
      routerConfig: router,
      builder: (context, child) => _MockBanner(
        visible: AppEnv.isMock,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Persistent environment marker — mock builds can never be mistaken for
/// production (`ENV=mock` only).
class _MockBanner extends StatelessWidget {
  const _MockBanner({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          child: SafeArea(
            right: false,
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: const BoxDecoration(
                color: ZColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Text(
                'PARTNER · MOCK',
                style: ZTypography.overline.copyWith(
                  color: ZColors.onPrimary,
                  fontSize: 9,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
