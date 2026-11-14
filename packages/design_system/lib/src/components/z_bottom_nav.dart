import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/motion.dart';
import '../tokens/radius.dart';
import '../tokens/typography.dart';

class ZBottomNavItem {
  const ZBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Branded bottom navigation: animated pill behind the active icon, springy
/// icon scale and a lime status dot. Replaces the stock Material NavigationBar
/// so both apps share identity and motion.
class ZBottomNav extends StatelessWidget {
  const ZBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<ZBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ZColors.surface,
        border: Border(top: BorderSide(color: ZColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavItem(
                    item: items[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ZBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: ZMotion.base,
              curve: ZMotion.standard,
              width: selected ? 46 : 36,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? ZColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(ZRadii.md),
              ),
              child: AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: ZMotion.base,
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 21,
                  color: selected ? ZColors.primary : ZColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: ZMotion.base,
              curve: ZMotion.standard,
              style: ZTypography.overline.copyWith(
                color: selected ? ZColors.primary : ZColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                letterSpacing: 0.3,
              ),
              child: Text(item.label),
            ),
            const SizedBox(height: 3),
            AnimatedOpacity(
              duration: ZMotion.base,
              opacity: selected ? 1 : 0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: ZColors.highlight,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
