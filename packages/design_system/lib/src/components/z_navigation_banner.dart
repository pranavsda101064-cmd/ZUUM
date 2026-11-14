import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Turn-by-turn banner: next maneuver icon, instruction and distance left to
/// the maneuver. Used by the partner navigation screen.
class ZNavigationBanner extends StatelessWidget {
  const ZNavigationBanner({
    super.key,
    required this.maneuverType,
    required this.instruction,
    required this.distanceLabel,
    this.remainingLabel,
    this.onTap,
  });

  /// Valhalla maneuver type (docs: https://valhalla.github.io/valhalla/api/turn-by-turn/api-reference/).
  final int maneuverType;
  final String instruction;
  final String distanceLabel;
  final String? remainingLabel;
  final VoidCallback? onTap;

  static IconData iconFor(int type) {
    const right = [
      Icons.turn_right_rounded,
      Icons.turn_slight_right_rounded,
      Icons.turn_sharp_right_rounded,
    ];
    const left = [
      Icons.turn_left_rounded,
      Icons.turn_slight_left_rounded,
      Icons.turn_sharp_left_rounded,
    ];
    if (right.contains(type)) return Icons.turn_right_rounded;
    if (left.contains(type)) return Icons.turn_left_rounded;
    switch (type) {
      case 9:
      case 10:
      case 18:
      case 20:
      case 23:
      case 37:
        return Icons.turn_right_rounded;
      case 11:
        return Icons.turn_sharp_right_rounded;
      case 12:
        return Icons.u_turn_right_rounded;
      case 13:
        return Icons.u_turn_left_rounded;
      case 14:
      case 15:
      case 19:
      case 21:
      case 24:
      case 38:
        return Icons.turn_left_rounded;
      case 16:
        return Icons.turn_sharp_left_rounded;
      case 26:
      case 27:
        return Icons.roundabout_right_rounded;
      case 4:
      case 5:
      case 6:
        return Icons.flag_rounded;
      case 1:
      case 2:
      case 3:
        return Icons.navigation_rounded;
      case 25:
      case 22:
        return Icons.merge_rounded;
      case 17:
        return Icons.straight_rounded;
      default:
        return Icons.straight_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(ZSpacing.md),
      decoration: BoxDecoration(
        color: ZColors.dark,
        borderRadius: BorderRadius.circular(ZRadii.lg),
        boxShadow: const [
          BoxShadow(
            color: ZColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: ZColors.highlight,
              borderRadius: BorderRadius.circular(ZRadii.md),
            ),
            child: Icon(
              iconFor(maneuverType),
              color: ZColors.dark,
              size: 26,
            ),
          ),
          const SizedBox(width: ZSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ZTypography.bodyStrong.copyWith(
                    color: ZColors.onDark,
                  ),
                ),
                if (remainingLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      remainingLabel!,
                      style: ZTypography.overline.copyWith(
                        color: ZColors.onDarkSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: ZSpacing.sm),
          Text(
            distanceLabel,
            style: ZTypography.numericLg.copyWith(
              color: ZColors.highlight,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }
}

/// Small honest chip shown when the route came from the haversine fallback.
class ZMapStatusChip extends StatelessWidget {
  const ZMapStatusChip({
    super.key,
    this.degraded = false,
    this.provider,
    this.onTap,
  });

  final bool degraded;
  final String? provider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = degraded
        ? 'Approximate route'
        : (provider == 'valhalla' ? 'Live route' : 'Route');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: degraded ? ZColors.errorTint : ZColors.highlightTint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: degraded ? ZColors.error.withValues(alpha: 0.3) : ZColors.highlight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              degraded ? Icons.wifi_off_rounded : Icons.bolt_rounded,
              size: 12,
              color: degraded ? ZColors.error : ZColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: ZTypography.overline.copyWith(
                color: degraded ? ZColors.error : ZColors.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
