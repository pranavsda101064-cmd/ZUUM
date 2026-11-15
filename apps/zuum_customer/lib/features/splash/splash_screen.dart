import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zuum_core/core.dart';
import 'package:zuum_design_system/design_system.dart';

import '../../app/auth_controller.dart';

/// Splash — the sole dark canvas in the app (Gemini spec §2a):
/// logomark stroke-draw → marigold dot pop → Kannada line fade,
/// with a determinate progress track and a connection-error sheet.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _dot = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final AnimationController _kannada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  bool _showNetworkHint = false;
  bool _errorShown = false;
  Timer? _hintTimer;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _logo.forward().then((_) => _dot.forward()).then((_) => _kannada.forward());
    _boot();
    // Spec: >2s → "Syncing live city routes..." caption.
    _hintTimer = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          ref.read(authControllerProvider).status == AuthStatus.unknown) {
        setState(() => _showNetworkHint = true);
      }
    });
    // Spec §2a Error — no network / stuck bootstrap after 6s.
    _errorTimer = Timer(const Duration(seconds: 6), () {
      if (mounted &&
          ref.read(authControllerProvider).status == AuthStatus.unknown &&
          !_errorShown) {
        _showConnectionError();
      }
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _errorTimer?.cancel();
    _logo.dispose();
    _dot.dispose();
    _kannada.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final auth = ref.read(authControllerProvider.notifier);
    final prefs = ref.read(prefsStoreProvider);

    try {
      final results = await Future.wait<Object?>([
        auth.bootstrap(),
        prefs.onboarded,
        Future<void>.delayed(const Duration(milliseconds: 1400)),
      ]);
      if (!mounted) return;
      final onboarded = results[1] as bool;
      final status = ref.read(authControllerProvider).status;
      if (status == AuthStatus.unauthenticated) {
        context.go(onboarded ? '/auth/login' : '/onboarding');
      }
      // Authenticated: router refresh (triggered by bootstrap) redirects to /home.
    } catch (_) {
      if (mounted && !_errorShown) _showConnectionError();
    }
  }

  void _showConnectionError() {
    if (_errorShown || !mounted) return;
    _errorShown = true;
    setState(() => _showNetworkHint = false);
    ZSheet.show<void>(
      context: context,
      title: 'Connection lost on the Outer Ring Road',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Check your mobile data or Wi-Fi to load live vehicles.',
            style: ZTypography.body.copyWith(color: ZColors.textSecondary),
          ),
          const SizedBox(height: ZSpacing.xl),
          ZButton(
            label: 'Retry connection',
            onPressed: () {
              Navigator.of(context).pop();
              _errorShown = false;
              _boot();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ZColors.dark,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 4),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logomark: Z tile with stroke-draw reveal + marigold pop.
                  AnimatedBuilder(
                    animation: Listenable.merge([_logo, _dot]),
                    builder: (context, _) {
                      return Column(
                        children: [
                          CustomPaint(
                            size: const Size(96, 96),
                            painter: _LogoPainter(
                              drawProgress: _logo.value,
                              dotScale: _dot.value,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'ZUUM',
                            style: ZTypography.display.copyWith(
                              color: ZColors.onDark,
                              letterSpacing: 4.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Old Bengaluru soul. New Bengaluru movement.',
                            style: ZTypography.caption.copyWith(
                              color: ZColors.accent,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _kannada,
              child: Padding(
                padding: const EdgeInsets.only(bottom: ZSpacing.xxl),
                child: Column(
                  children: [
                    Text(
                      'ನಮ್ಮ ಬೆಂಗಳೂರು, ನಮ್ಮ ಪಯಣ',
                      style: ZTypography.kannada(
                        fontSize: 13,
                        color: ZColors.accent,
                      ),
                    ),
                    const SizedBox(height: ZSpacing.lg),
                    // Determinate progress track (96×2).
                    SizedBox(
                      width: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: ZColors.textSecondary,
                          color: ZColors.accent,
                          value: _logo.value,
                        ),
                      ),
                    ),
                    const SizedBox(height: ZSpacing.sm),
                    AnimatedOpacity(
                      duration: ZMotion.base,
                      opacity: _showNetworkHint ? 1 : 0,
                      child: Text(
                        'Syncing live city routes...',
                        style: ZTypography.overline.copyWith(
                          color: ZColors.textTertiary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.drawProgress, required this.dotScale});

  final double drawProgress;
  final double dotScale;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(24),
    );
    // Stroke-draw the tile outline.
    final outline = Paint()
      ..color = ZColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics().first;
    final drawn = metrics.extractPath(0, metrics.length * drawProgress);
    canvas.drawPath(drawn, outline);

    // The Z inside.
    if (drawProgress > 0.6) {
      final zPaint = Paint()
        ..color = ZColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      final z = Path();
      final inset = size.width * 0.3;
      z.moveTo(inset, inset);
      z.lineTo(size.width - inset, inset);
      z.lineTo(inset, size.height - inset);
      z.lineTo(size.width - inset, size.height - inset);
      canvas.drawPath(z, zPaint);
    }

    // Marigold motion dot (pops with easeOutBack).
    if (dotScale > 0) {
      final dot = Paint()..color = ZColors.onDark;
      final center = Offset(size.width * 0.78, size.height * 0.78);
      canvas.drawCircle(center, 9 * dotScale, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.drawProgress != drawProgress ||
      oldDelegate.dotScale != dotScale;
}
