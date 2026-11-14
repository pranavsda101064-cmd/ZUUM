import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_live_dot.dart';

/// Partner online/offline hero — carbon card with a live dot, big touch
/// friendly switch and a one-line status. The single most important control
/// in the driver app.
class ZOnlineHero extends StatelessWidget {
  const ZOnlineHero({
    super.key,
    required this.online,
    required this.onChanged,
    this.busy = false,
    this.title,
    this.subtitle,
    this.earningsLabel,
  });

  final bool online;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final String? title;
  final String? subtitle;
  final String? earningsLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZSpacing.xl),
      decoration: BoxDecoration(
        color: ZColors.dark,
        borderRadius: BorderRadius.circular(ZRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZLiveDot(color: online ? ZColors.highlight : ZColors.textTertiary),
              const SizedBox(width: ZSpacing.sm),
              Text(
                online ? 'ONLINE' : 'OFFLINE',
                style: ZTypography.overline.copyWith(
                  color: online ? ZColors.highlight : ZColors.onDarkSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              if (earningsLabel != null)
                Text(
                  earningsLabel!,
                  style: ZTypography.numeric.copyWith(
                    color: ZColors.accent,
                    fontSize: 14,
                  ),
                ),
            ],
          ),
          const SizedBox(height: ZSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  title ??
                      (online
                          ? 'Receiving trips in Bengaluru'
                          : 'Go online to receive trips'),
                  style: ZTypography.titleMd.copyWith(color: ZColors.onDark),
                ),
              ),
              const SizedBox(width: ZSpacing.md),
              // 56dp touch target maintained by MaterialTapTargetSize.
              Switch(
                value: online,
                onChanged: busy ? null : onChanged,
                activeTrackColor: ZColors.highlight,
                inactiveTrackColor: ZColors.darkRaised,
                activeThumbColor: ZColors.dark,
                inactiveThumbColor: ZColors.onDarkSecondary,
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: ZSpacing.xs),
            Text(
              busy ? 'Updating availability…' : subtitle!,
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
