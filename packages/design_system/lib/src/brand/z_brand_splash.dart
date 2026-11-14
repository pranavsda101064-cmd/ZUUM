import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../brand/z_brand_mark.dart';
import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Production splash: animated brand reveal on carbon ink with a soft lime
/// glow, Kannada micro-line and an indeterminate hairline loader.
///
/// The screen is purely visual; the owning app drives bootstrap timing and
/// routing so session restore never fights the animation.
class ZBrandSplash extends StatefulWidget {
  const ZBrandSplash({
    super.key,
    this.badge,
    this.tagline,
    this.kannada,
    this.footnote,
    this.showLoader = true,
  });

  /// Optional lime pill under the wordmark (e.g. "PARTNER").
  final String? badge;
  final String? tagline;
  final String? kannada;
  final String? footnote;
  final bool showLoader;

  @override
  State<ZBrandSplash> createState() => _ZBrandSplashState();
}

class _ZBrandSplashState extends State<ZBrandSplash>
    with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final Animation<double> _logo = CurvedAnimation(
    parent: _reveal,
    curve: const Interval(0, 0.55, curve: Cubic(0.16, 1, 0.3, 1)),
  );
  late final Animation<double> _dot = CurvedAnimation(
    parent: _reveal,
    curve: const Interval(0.35, 0.7, curve: Curves.elasticOut),
  );
  late final Animation<double> _text = CurvedAnimation(
    parent: _reveal,
    curve: const Interval(0.5, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _reveal.forward();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) _reveal.value = 1;

    return Scaffold(
      backgroundColor: ZColors.dark,
      body: Stack(
        children: [
          const Positioned.fill(child: _GlowPainterWidget()),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_reveal, _float]),
                builder: (context, _) {
                  final drift = reduce ? 0.0 : math.sin(_float.value * math.pi) * 4;
                  return Transform.translate(
                    offset: Offset(0, drift),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: _logo.value,
                          child: Transform.scale(
                            scale: 0.86 + (0.14 * _logo.value),
                            child: Align(
                              alignment: Alignment.center,
                              child: ZBrandMark(scale: 1.8, onDark: true),
                            ),
                          ),
                        ),
                        if (widget.badge != null) ...[
                          const SizedBox(height: 10),
                          Opacity(
                            opacity: _dot.value.clamp(0, 1),
                            child: Transform.scale(
                              scale: _dot.value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ZColors.highlight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  widget.badge!,
                                  style: ZTypography.overline.copyWith(
                                    color: ZColors.dark,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: ZSpacing.z40),
                        Opacity(
                          opacity: _text.value,
                          child: Column(
                            children: [
                              if (widget.kannada != null)
                                Text(
                                  widget.kannada!,
                                  style: ZTypography.kannada(
                                    fontSize: 13,
                                    color: ZColors.accent,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              if (widget.tagline != null) ...[
                                const SizedBox(height: ZSpacing.xs),
                                Text(
                                  widget.tagline!,
                                  style: ZTypography.caption.copyWith(
                                    color: ZColors.onDarkSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (widget.showLoader)
            Positioned(
              left: 0,
              right: 0,
              bottom: 64,
              child: FadeTransition(
                opacity: _text,
                child: const Center(child: _HairlineLoader()),
              ),
            ),
          if (widget.footnote != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: FadeTransition(
                opacity: _text,
                child: Text(
                  widget.footnote!,
                  textAlign: TextAlign.center,
                  style: ZTypography.overline.copyWith(
                    color: ZColors.onDarkSecondary.withValues(alpha: 0.6),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft lime radial glow + faint dotted grain, matching the brand canvas.
class _GlowPainterWidget extends StatelessWidget {
  const _GlowPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GlowPainter());
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.38);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          ZColors.highlight.withValues(alpha: 0.16),
          ZColors.highlight.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.shortestSide * 0.55),
      );
    canvas.drawCircle(center, size.shortestSide * 0.55, glow);

    final grain = Paint()
      ..color = ZColors.onDark.withValues(alpha: 0.05)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const step = 26.0;
    for (var x = step; x < size.width; x += step) {
      for (var y = step; y < size.height * 0.9; y += step) {
        final wobble = ((x * 7919 + y * 104729) % 13) / 13;
        if (wobble > 0.55) continue;
        canvas.drawPoints(
          ui.PointMode.points,
          [Offset(x + wobble * 6, y + wobble * 4)],
          grain,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Indeterminate travel-line loader (lime segment gliding on a track).
class _HairlineLoader extends StatefulWidget {
  const _HairlineLoader();

  @override
  State<_HairlineLoader> createState() => _HairlineLoaderState();
}

class _HairlineLoaderState extends State<_HairlineLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: ZColors.onDark.withValues(alpha: 0.14),
                ),
              ),
              Align(
                alignment: Alignment(-1 + t * 2, 0),
                child: Container(
                  width: 42,
                  height: 2,
                  decoration: BoxDecoration(
                    color: ZColors.highlight,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: ZColors.highlight.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
