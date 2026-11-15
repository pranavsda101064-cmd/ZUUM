import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Bundled, color-graded photography shipped with the design system.
/// Loads `packages/zuum_design_system/assets/photos/{name}.webp`.
class ZPhoto extends StatelessWidget {
  const ZPhoto(
    this.name, {
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.fallback,
  });

  final String name;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/photos/$name.webp',
      package: 'zuum_design_system',
      fit: fit,
      alignment: alignment,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: ZMotion.slow,
          curve: ZMotion.standard,
          child: child,
        );
      },
      errorBuilder: (context, error, stack) =>
          fallback ??
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ZColors.primaryTint, ZColors.accent],
              ),
            ),
          ),
    );
  }
}

/// Gradient scrim used over photography (never render text on raw photos).
class ZScrim extends StatelessWidget {
  const ZScrim({
    super.key,
    this.alignment = Alignment.bottomCenter,
    this.opacity = 0.78,
  });

  final AlignmentGeometry alignment;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: alignment == Alignment.topCenter
              ? Alignment.topCenter
              : Alignment.topCenter,
          end: alignment,
          colors: [
            ZColors.dark.withValues(alpha: opacity * 0.25),
            ZColors.dark.withValues(alpha: opacity),
          ],
        ),
      ),
    );
  }
}

/// Editorial photo header with a dark scrim and overlay content.
class ZPhotoHero extends StatelessWidget {
  const ZPhotoHero({
    super.key,
    required this.photo,
    this.height = 240,
    this.alignment = Alignment.center,
    this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(ZRadii.lg)),
    this.caption,
  });

  final String photo;
  final double height;
  final Alignment alignment;
  final Widget? child;
  final BorderRadius borderRadius;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ZPhoto(photo, alignment: alignment),
            const ZScrim(),
            Padding(
              padding: const EdgeInsets.all(ZSpacing.lg),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption != null)
                      Text(
                        caption!,
                        style: ZTypography.overline.copyWith(
                          color: ZColors.onDark,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ?child,
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

/// Card with an image top and a structured body.
class ZImageCard extends StatelessWidget {
  const ZImageCard({
    super.key,
    required this.photo,
    required this.child,
    this.imageHeight = 136,
    this.tag,
    this.onTap,
  });

  final String photo;
  final Widget child;
  final double imageHeight;
  final String? tag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(ZRadii.lg),
      child: Container(
        decoration: BoxDecoration(
          color: ZColors.surface,
          borderRadius: BorderRadius.circular(ZRadii.lg),
          border: Border.all(color: ZColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: imageHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ZPhoto(photo),
                  Positioned(
                    left: ZSpacing.sm,
                    top: ZSpacing.sm,
                    child: tag == null
                        ? const SizedBox.shrink()
                        : Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: ZColors.surface.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              tag!,
                              style: ZTypography.overline.copyWith(
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(ZSpacing.md), child: child),
          ],
        ),
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.lg),
      child: content,
    );
  }
}

/// Frosted panel for floating UI over the map.
class ZGlassPanel extends StatelessWidget {
  const ZGlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZSpacing.lg),
    this.borderRadius = const BorderRadius.all(Radius.circular(ZRadii.lg)),
    this.blur = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ZColors.surface.withValues(alpha: 0.82),
            borderRadius: borderRadius,
            border: Border.all(color: ZColors.surface.withValues(alpha: 0.9)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section title + optional trailing action.
class ZSectionHeader extends StatelessWidget {
  const ZSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZTypography.titleMd),
                if (caption != null)
                  Text(
                    caption!,
                    style: ZTypography.caption
                        .copyWith(color: ZColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: ZTypography.captionStrong
                    .copyWith(color: ZColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Icon inside a tinted, rounded tile (standardizes iconography).
class ZIconTile extends StatelessWidget {
  const ZIconTile({
    super.key,
    required this.icon,
    this.size = 40,
    this.iconSize = 20,
    this.background = ZColors.primaryTint,
    this.foreground = ZColors.primary,
    this.radius = ZRadii.md,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color background;
  final Color foreground;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

/// Label/value row used in summaries and receipts.
class ZMetricRow extends StatelessWidget {
  const ZMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(vertical: 4),
  });

  final String label;
  final String value;
  final bool emphasize;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: ZTypography.caption.copyWith(
                color: emphasize ? ZColors.textPrimary : ZColors.textSecondary,
                fontWeight: emphasize ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (trailing != null) ...[trailing!, const SizedBox(width: 6)],
          Text(
            value,
            style: (emphasize
                    ? ZTypography.numericLg
                    : ZTypography.numeric)
                .copyWith(fontSize: emphasize ? 18 : 15),
          ),
        ],
      ),
    );
  }
}
