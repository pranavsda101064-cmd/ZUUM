import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// App bar — left-aligned title (Uber-like), optional back, actions, subtitle.
class ZAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ZAppBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showBack = false,
    this.onBack,
    this.bottom,
    this.backgroundColor,
    this.centerTitle = false,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final canPop = showBack || Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: backgroundColor ?? ZColors.background,
      surfaceTintColor: Colors.transparent,
      leading: canPop
          ? IconButton(
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      automaticallyImplyLeading: false,
      centerTitle: centerTitle,
      titleSpacing: canPop ? 0 : ZSpacing.lg,
      title: title == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title!, style: ZTypography.titleMd),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: ZTypography.caption.copyWith(
                      color: ZColors.textSecondary,
                    ),
                  ),
              ],
            ),
      actions: [
        for (final action in actions) ...[action, const SizedBox(width: 4)],
        const SizedBox(width: ZSpacing.sm),
      ],
      bottom: bottom,
    );
  }
}
