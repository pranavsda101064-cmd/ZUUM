import 'package:flutter/material.dart';

import '../format/z_format.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import 'z_badge.dart';

enum ZDocStatus { missing, pending, verified, expired }

/// KYC document row — label, upload state, expiry warning and action.
class ZDocumentTile extends StatelessWidget {
  const ZDocumentTile({
    super.key,
    required this.label,
    required this.status,
    this.fileName,
    this.expiresAt,
    this.onTap,
  });

  final String label;
  final ZDocStatus status;
  final String? fileName;
  final DateTime? expiresAt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (badge, tone, icon, iconColor) = switch (status) {
      ZDocStatus.missing => (
          'Upload',
          ZBadgeTone.neutral,
          Icons.upload_file_outlined,
          ZColors.textTertiary,
        ),
      ZDocStatus.pending => (
          'Pending',
          ZBadgeTone.highlight,
          Icons.hourglass_top_rounded,
          ZColors.textSecondary,
        ),
      ZDocStatus.verified => (
          'Verified',
          ZBadgeTone.success,
          Icons.verified_outlined,
          ZColors.success,
        ),
      ZDocStatus.expired => (
          'Expired',
          ZBadgeTone.error,
          Icons.warning_amber_rounded,
          ZColors.error,
        ),
    };

    final subtitleParts = <String>[
      if (fileName != null && fileName!.isNotEmpty) fileName!,
      if (expiresAt != null) 'Valid till ${ZFormat.shortDate(expiresAt!)}',
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.md),
      child: Container(
        padding: const EdgeInsets.all(ZSpacing.md),
        decoration: BoxDecoration(
          color: ZColors.surface,
          borderRadius: BorderRadius.circular(ZRadii.md),
          border: Border.all(
            color: status == ZDocStatus.expired
                ? ZColors.error
                : ZColors.divider,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ZColors.background,
                borderRadius: BorderRadius.circular(ZRadii.sm),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: ZSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ZTypography.bodyStrong),
                  if (subtitleParts.isNotEmpty)
                    Text(
                      subtitleParts.join(' · '),
                      style: ZTypography.caption.copyWith(
                        color: ZColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: ZSpacing.sm),
            ZBadge(label: badge, tone: tone),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: ZSpacing.xs),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: ZColors.textTertiary,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
