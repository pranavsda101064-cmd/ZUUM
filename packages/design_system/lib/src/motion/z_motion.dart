import 'package:flutter/material.dart';

import '../tokens/motion.dart';

/// Global page transition: fade-through + a short upward drift. Applied via
/// `PageTransitionsTheme` so every pushed route (GoRouter or Navigator) shares
/// the same physics.
class ZPageTransitionsBuilder extends PageTransitionsBuilder {
  const ZPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.16, 1, 0.3, 1),
      reverseCurve: Curves.easeInCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(curved);
    final scale = Tween<double>(begin: 0.985, end: 1).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}

/// Fade-through used for hero-less auth steps (register, forgot, KYC steps).
class ZFadeThroughTransitionsBuilder extends PageTransitionsBuilder {
  const ZFadeThroughTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

/// Sensible defaults per platform.
const zPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ZPageTransitionsBuilder(),
    TargetPlatform.iOS: ZPageTransitionsBuilder(),
    TargetPlatform.macOS: ZPageTransitionsBuilder(),
    TargetPlatform.windows: ZPageTransitionsBuilder(),
    TargetPlatform.linux: ZPageTransitionsBuilder(),
  },
);

/// Staggered entrance: fade + rise, delayed by `index * step`. Honors the
/// platform "reduce motion" accessibility flag.
class ZEntrance extends StatefulWidget {
  const ZEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 70),
    this.duration = ZMotion.slow,
    this.offset = const Offset(0, 0.06),
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration duration;
  final Offset offset;

  @override
  State<ZEntrance> createState() => _ZEntranceState();
}

class _ZEntranceState extends State<ZEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: const Cubic(0.16, 1, 0.3, 1),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
      return;
    }
    Future<void>.delayed(widget.step * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: widget.offset,
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// Smoothly counts up/down when [value] changes (money, counts, ratings).
class ZAnimatedCounter extends StatelessWidget {
  const ZAnimatedCounter({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = const Duration(milliseconds: 650),
    this.textAlign,
  });

  final num value;
  final String Function(num value) format;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return Text(format(value), style: style, textAlign: textAlign);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(
        format(animated.round()),
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

/// Scale-on-press wrapper for custom tappables.
class ZPressable extends StatefulWidget {
  const ZPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<ZPressable> createState() => _ZPressableState();
}

class _ZPressableState extends State<ZPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: ZMotion.fast,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
