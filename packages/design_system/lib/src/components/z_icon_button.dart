import 'package:flutter/material.dart';

import '../tokens/colors.dart';

/// Circular icon button with optional tinted background.
class ZIconButton extends StatelessWidget {
  const ZIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.background = Colors.transparent,
    this.foreground = ZColors.textPrimary,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? ZColors.surface : background;
    final button = IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
      style: IconButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size / 2),
          side: filled ? const BorderSide(color: ZColors.divider) : BorderSide.none,
        ),
      ),
      icon: Icon(icon, size: iconSize),
    );
    return button;
  }
}
