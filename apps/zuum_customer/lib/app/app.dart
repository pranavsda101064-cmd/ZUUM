import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import 'router.dart';

class ZuumApp extends ConsumerWidget {
  const ZuumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Zuum',
      debugShowCheckedModeBanner: false,
      theme: ZuumTheme.light(),
      routerConfig: router,
      builder: (context, child) => _DevBanner(
        visible: AppEnv.isMock,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Persistent environment marker so mock builds can never be mistaken for
/// production (`ENV=mock` only).
class _DevBanner extends StatelessWidget {
  const _DevBanner({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    return Stack(
      children: [
        child,
        const Positioned(
          right: 0,
          top: 0,
          child: SafeArea(
            right: false,
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(right: 4),
              child: _MockTag(),
            ),
          ),
        ),
      ],
    );
  }
}

class _MockTag extends StatelessWidget {
  const _MockTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: const BoxDecoration(
        color: ZColors.highlight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(6),
          bottomLeft: Radius.circular(6),
        ),
      ),
      child: Text(
        'ENV: MOCK',
        style: ZTypography.overline.copyWith(
          color: ZColors.dark,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
