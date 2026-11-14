import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/typography.dart';

/// Initials avatar (network photos arrive in later milestones; initials are
/// the honest default until then).
class ZAvatar extends StatelessWidget {
  const ZAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.imageUrl,
  });

  final String initials;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: ZColors.accent, shape: BoxShape.circle),
      child: Text(
        initials.toUpperCase(),
        style: (size >= 40 ? ZTypography.bodyStrong : ZTypography.captionStrong)
            .copyWith(color: ZColors.primary),
      ),
    );
  }
}
