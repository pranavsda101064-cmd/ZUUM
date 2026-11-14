import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

/// Segmented switch (Ride | Send Goods) — 48dp container, active tab filled
/// Primary with Surface text; slides in place over 220ms.
class ZSegmentedSwitch extends StatelessWidget {
  const ZSegmentedSwitch({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<ZSegment> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ZColors.background,
        borderRadius: BorderRadius.circular(ZRadii.md),
        border: Border.all(color: ZColors.divider),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            Expanded(
              child: _SegmentTile(
                segment: segments[i],
                selected: i == selectedIndex,
                onTap: () => onChanged(i),
              ),
            ),
            if (i != segments.length - 1) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

class ZSegment {
  const ZSegment({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final ZSegment segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZRadii.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? ZColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(ZRadii.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (segment.icon != null) ...[
              Icon(
                segment.icon,
                size: 18,
                color: selected ? ZColors.onPrimary : ZColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              segment.label,
              style: ZTypography.bodyStrong.copyWith(
                color: selected ? ZColors.onPrimary : ZColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
