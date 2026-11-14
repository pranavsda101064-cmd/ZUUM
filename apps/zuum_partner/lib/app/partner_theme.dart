import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

/// Partner visual identity: same Obsidian/Lime token system as the customer
/// app, but with a carbon-ink app bar shell so the two apps read as siblings
/// with different jobs (driver utility vs consumer).
abstract final class PartnerTheme {
  static ThemeData light() {
    final base = ZuumTheme.light();
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: ZColors.dark,
        foregroundColor: ZColors.onDark,
        titleTextStyle: ZTypography.titleMd.copyWith(color: ZColors.onDark),
        iconTheme: const IconThemeData(color: ZColors.onDark),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ZColors.surface,
        indicatorColor: ZColors.accent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll(ZTypography.overline),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? ZColors.primary
                : ZColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
