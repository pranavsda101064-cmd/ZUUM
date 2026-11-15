import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZSpacing.lg),
    this.color,
    this.border = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? ZColors.darkSurface,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: border ? Border.all(color: ZColors.darkOutline) : null,
      ),
      child: child,
    );
  }
}

class AdminEyebrow extends StatelessWidget {
  const AdminEyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: ZTypography.overline.copyWith(
        color: color ?? ZColors.onDarkSecondary,
        letterSpacing: 1.2,
      ),
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: ZTypography.titleMd.copyWith(color: ZColors.onDark),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  style: ZTypography.caption.copyWith(
                    color: ZColors.onDarkSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: ZSpacing.md),
          trailing!,
        ],
      ],
    );
  }
}

enum AdminTone { neutral, success, warning, danger, info }

class AdminPill extends StatelessWidget {
  const AdminPill({
    super.key,
    required this.label,
    this.tone = AdminTone.neutral,
    this.dot = false,
  });

  final String label;
  final AdminTone tone;
  final bool dot;

  Color get _color => switch (tone) {
        AdminTone.success => ZColors.success,
        AdminTone.warning => ZColors.warning,
        AdminTone.danger => ZColors.error,
        AdminTone.info => ZColors.onDark,
        AdminTone.neutral => ZColors.onDarkSecondary,
      };

  static AdminTone toneFor(String status) {
    final value = status.toLowerCase();
    if (value.contains('complet') ||
        value.contains('active') ||
        value.contains('paid') ||
        value.contains('verified') ||
        value == 'approved') {
      return AdminTone.success;
    }
    if (value.contains('cancel') ||
        value.contains('reject') ||
        value.contains('suspend') ||
        value.contains('fail') ||
        value.contains('sos') ||
        value.contains('urgent')) {
      return AdminTone.danger;
    }
    if (value.contains('pending') ||
        value.contains('submit') ||
        value.contains('process') ||
        value.contains('assigned') ||
        value.contains('arriv') ||
        value.contains('search') ||
        value.contains('progress') ||
        value.contains('open')) {
      return AdminTone.warning;
    }
    return AdminTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: ZTypography.overline.copyWith(
              color: _color,
              fontSize: 10,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminButton extends StatelessWidget {
  const AdminButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.danger = false,
    this.busy = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final bool busy;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || busy;
    final color = danger
        ? ZColors.error.withValues(alpha: 0.10)
        : primary
            ? ZColors.onDark
            : ZColors.darkRaised.withValues(alpha: 0.65);
    final foreground = primary
        ? ZColors.dark
        : danger
            ? ZColors.error
            : ZColors.onDark;
    return Material(
      color: disabled ? color.withValues(alpha: 0.4) : color,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(ZRadii.md),
        hoverColor: ZColors.onDark.withValues(alpha: 0.06),
        child: Container(
          height: compact ? 32 : 38,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ZRadii.md),
            border: primary
                ? null
                : Border.all(
                    color: danger
                        ? ZColors.error.withValues(alpha: 0.35)
                        : ZColors.darkOutline,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: foreground,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 15, color: foreground),
              if (busy || icon != null) const SizedBox(width: 7),
              Text(
                label,
                style: ZTypography.captionStrong.copyWith(
                  color: foreground,
                  fontSize: compact ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSearch extends StatelessWidget {
  const AdminSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: ZTypography.body.copyWith(color: ZColors.onDark, fontSize: 13),
        cursorColor: ZColors.onDark,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ZTypography.caption.copyWith(
            color: ZColors.onDarkSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 17,
            color: ZColors.onDarkSecondary,
          ),
          filled: true,
          fillColor: ZColors.darkRaised.withValues(alpha: 0.45),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZRadii.md),
            borderSide: const BorderSide(color: ZColors.darkOutline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZRadii.md),
            borderSide: const BorderSide(color: ZColors.darkOutline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ZRadii.md),
            borderSide: const BorderSide(color: ZColors.onDarkSecondary),
          ),
        ),
      ),
    );
  }
}

class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final option in options)
          Material(
            color: value == option
                ? ZColors.onDark
                : ZColors.darkRaised.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: value == option
                        ? ZColors.onDark
                        : ZColors.darkOutline,
                  ),
                ),
                child: Text(
                  option.toUpperCase(),
                  style: ZTypography.overline.copyWith(
                    color: value == option
                        ? ZColors.dark
                        : ZColors.onDarkSecondary,
                    fontSize: 10,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    this.accent = false,
    this.tone,
    this.bars,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final bool accent;
  final Color? tone;
  final List<int>? bars;

  @override
  Widget build(BuildContext context) {
    final accentColor = tone ?? ZColors.onDark;
    return AdminPanel(
      color: accent ? ZColors.darkRaised : ZColors.darkSurface,
      padding: const EdgeInsets.all(ZSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: accent ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(ZRadii.sm),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const Spacer(),
              if (bars != null)
                SizedBox(
                  width: 72,
                  height: 28,
                  child: _MiniBars(values: bars!, color: accentColor),
                ),
            ],
          ),
          const SizedBox(height: ZSpacing.lg),
          Text(
            value,
            style: ZTypography.numericLg.copyWith(
              color: ZColors.onDark,
              fontSize: 28,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: ZTypography.captionStrong.copyWith(
              color: ZColors.onDarkSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: ZTypography.caption.copyWith(
              color: ZColors.onDarkSecondary.withValues(alpha: 0.8),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  const _MiniBars({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty ? 1 : values.reduce(math.max).clamp(1, 1 << 30);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 2),
              child: FractionallySizedBox(
                heightFactor: math.max(0.08, value / maxValue),
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.label, this.size = 34});
  final String label;
  final double size;

  String get initials {
    final parts = label.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ZColors.onDark.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: ZColors.darkOutline),
      ),
      child: Text(
        initials,
        style: ZTypography.captionStrong.copyWith(
          color: ZColors.onDark,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZSpacing.xxl),
      child: Column(
        children: [
          Icon(icon, size: 28, color: ZColors.onDarkSecondary),
          const SizedBox(height: ZSpacing.sm),
          Text(
            title,
            style: ZTypography.bodyStrong.copyWith(color: ZColors.onDark),
          ),
          if (message != null) ...[
            const SizedBox(height: 2),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: ZTypography.caption.copyWith(
                color: ZColors.onDarkSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminError extends StatelessWidget {
  const AdminError({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: ZColors.error),
          const SizedBox(height: ZSpacing.sm),
          Text(
            message,
            style: ZTypography.bodyStrong.copyWith(color: ZColors.onDark),
          ),
          const SizedBox(height: ZSpacing.md),
          AdminButton(label: 'Retry', icon: Icons.refresh_rounded, onPressed: onRetry),
        ],
      ),
    );
  }
}

class AdminSkeleton extends StatelessWidget {
  const AdminSkeleton({super.key, this.height = 120, this.width});
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: ZColors.darkRaised.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(ZRadii.lg),
        border: Border.all(color: ZColors.darkOutline),
      ),
    );
  }
}

class AdminTableHeader extends StatelessWidget {
  const AdminTableHeader({super.key, required this.cells, this.widths});
  final List<String> cells;
  final List<int>? widths;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: ZColors.darkOutline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            widths != null
                ? Expanded(
                    flex: widths![i],
                    child: Text(
                      cells[i].toUpperCase(),
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onDarkSecondary,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  )
                : Expanded(
                    child: Text(
                      cells[i].toUpperCase(),
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onDarkSecondary,
                        fontSize: 10,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
        ],
      ),
    );
  }
}

class AdminPager extends StatelessWidget {
  const AdminPager({
    super.key,
    required this.page,
    required this.total,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int total;
  final int pageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final pages = math.max(1, (total / pageSize).ceil());
    return Row(
      children: [
        Text(
          '$total records',
          style: ZTypography.caption.copyWith(color: ZColors.onDarkSecondary),
        ),
        const Spacer(),
        AdminButton(
          label: 'Previous',
          icon: Icons.chevron_left_rounded,
          compact: true,
          onPressed: onPrevious,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '$page / $pages',
            style: ZTypography.captionStrong.copyWith(
              color: ZColors.onDarkSecondary,
            ),
          ),
        ),
        AdminButton(
          label: 'Next',
          icon: Icons.chevron_right_rounded,
          compact: true,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class AdminTrendChart extends StatelessWidget {
  const AdminTrendChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 190,
  });

  final List<int> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1
        : values.reduce(math.max).clamp(1, 1 << 30);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: math.max(0.025, values[i] / maxValue),
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == values.length - 1
                                  ? ZColors.onDark
                                  : ZColors.onDark.withValues(alpha: 0.28),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[i],
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onDarkSecondary,
                        fontSize: 9,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
