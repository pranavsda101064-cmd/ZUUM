import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_avatar.dart';
import 'z_icon_button.dart';
import 'z_rating_stars.dart';

/// Assigned-driver card: identity, rating, vehicle, contact actions.
class ZDriverCard extends StatelessWidget {
  const ZDriverCard({
    super.key,
    required this.name,
    required this.rating,
    required this.vehicleLine,
    required this.plate,
    this.initials = 'D',
    this.photoUrl,
    this.onCall,
    this.onMessage,
    this.trailing,
  });

  final String name;
  final double rating;
  final String vehicleLine;
  final String plate;
  final String initials;
  final String? photoUrl;
  final VoidCallback? onCall;
  final VoidCallback? onMessage;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ZAvatar(initials: initials, imageUrl: photoUrl, size: 48),
        const SizedBox(width: ZSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: ZTypography.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: ZSpacing.sm),
                  ZRatingStars(rating: rating, size: 14),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$vehicleLine · ${plate.toUpperCase()}',
                style: ZTypography.caption.copyWith(color: ZColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onCall != null)
          ZIconButton(
            icon: Icons.call_rounded,
            filled: true,
            foreground: ZColors.primary,
            size: 40,
            onPressed: onCall,
            tooltip: 'Call driver',
          ),
        if (onMessage != null) ...[
          const SizedBox(width: ZSpacing.sm),
          ZIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            filled: true,
            foreground: ZColors.primary,
            size: 40,
            onPressed: onMessage,
            tooltip: 'Message driver',
          ),
        ],
        if (trailing != null) trailing!,
      ],
    );
  }
}
