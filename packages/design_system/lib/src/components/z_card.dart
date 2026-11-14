import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';

class ZCard extends StatelessWidget {
  const ZCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZSpacing.lg),
    this.onTap,
    this.radius = ZRadii.lg,
    this.highlighted = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool highlighted;
  final Color? color;

  static const shadow = [
    BoxShadow(
      color: ZColors.shadow,
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: ZColors.shadowSoft,
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final background = color ?? (highlighted ? ZColors.accent : ZColors.surface);
    final border = highlighted
        ? Border.all(color: ZColors.primary, width: 1)
        : Border.all(color: ZColors.divider);

    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: onTap == null ? shadow : const [],
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      ),
    );
  }
}
