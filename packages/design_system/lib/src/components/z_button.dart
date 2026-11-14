import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

enum ZButtonVariant { primary, secondary, ghost, danger }

enum ZButtonSize { sm, md, lg }

/// The one action button. One primary per screen — use variants deliberately.
class ZButton extends StatelessWidget {
  const ZButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ZButtonVariant.primary,
    this.size = ZButtonSize.md,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final ZButtonVariant variant;
  final ZButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool expand;

  double get _height => switch (size) {
        ZButtonSize.sm => 40,
        ZButtonSize.md => 48,
        ZButtonSize.lg => 56,
      };

  TextStyle get _textStyle => switch (size) {
        ZButtonSize.sm => ZTypography.captionStrong,
        ZButtonSize.md || ZButtonSize.lg => ZTypography.bodyStrong,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (background, foreground, border) = _palette(enabled);

    final content = loading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: ZSpacing.sm),
              ],
              Text(label, style: _textStyle.copyWith(color: foreground)),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.md),
          side: border ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(ZRadii.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: _height,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: ZSpacing.xl),
            alignment: Alignment.center,
            child: content,
          ),
        ),
      ),
    );
  }

  (Color, Color, BorderSide?) _palette(bool enabled) {
    if (!enabled) {
      return switch (variant) {
        ZButtonVariant.primary || ZButtonVariant.danger => (
            ZColors.disabled,
            ZColors.textSecondary,
            null,
          ),
        ZButtonVariant.secondary => (ZColors.surface, ZColors.textTertiary,
            const BorderSide(color: ZColors.divider)),
        ZButtonVariant.ghost => (Colors.transparent, ZColors.textTertiary, null),
      };
    }
    return switch (variant) {
      ZButtonVariant.primary => (ZColors.primary, ZColors.onPrimary, null),
      ZButtonVariant.danger => (ZColors.error, ZColors.onPrimary, null),
      ZButtonVariant.secondary => (
          ZColors.primaryTint,
          ZColors.primary,
          null,
        ),
      ZButtonVariant.ghost => (Colors.transparent, ZColors.primary, null),
    };
  }
}
