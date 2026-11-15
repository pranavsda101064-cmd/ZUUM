import 'package:flutter/material.dart';
import 'package:zuum_design_system/design_system.dart';

ThemeData adminTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: ZColors.dark,
    canvasColor: ZColors.dark,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: ZColors.onDark,
      onPrimary: ZColors.dark,
      surface: ZColors.darkSurface,
      onSurface: ZColors.onDark,
      outline: ZColors.darkOutline,
      error: ZColors.error,
    ),
    dividerColor: ZColors.darkOutline,
    textTheme: base.textTheme.apply(
      fontFamily: 'Inter',
      bodyColor: ZColors.onDark,
      displayColor: ZColors.onDark,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: ZColors.darkRaised,
        borderRadius: BorderRadius.all(Radius.circular(ZRadii.sm)),
      ),
      textStyle: TextStyle(color: ZColors.onDark, fontSize: 12),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(
        ZColors.onDark.withValues(alpha: 0.18),
      ),
      radius: const Radius.circular(999),
      thickness: const WidgetStatePropertyAll(8),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: ZColors.onDark,
      selectionColor: ZColors.darkOutline,
      selectionHandleColor: ZColors.onDark,
    ),
  );
}
