import 'package:flutter/material.dart';

import '../motion/z_motion.dart';
import '../tokens/colors.dart';
import '../tokens/radius.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// Zuum light theme — Uber-like restraint: monochrome surfaces,
/// one action color per screen, highlight used sparingly.
abstract final class ZuumTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: ZColors.primary,
      onPrimary: ZColors.onPrimary,
      primaryContainer: ZColors.primaryTint,
      onPrimaryContainer: ZColors.primary,
      secondary: ZColors.highlight,
      onSecondary: ZColors.dark,
      secondaryContainer: ZColors.highlightTint,
      onSecondaryContainer: ZColors.dark,
      error: ZColors.error,
      onError: ZColors.onPrimary,
      errorContainer: ZColors.errorTint,
      onErrorContainer: ZColors.error,
      surface: isLight ? ZColors.surface : ZColors.dark,
      onSurface: isLight ? ZColors.textPrimary : ZColors.onDark,
      onSurfaceVariant: isLight ? ZColors.textSecondary : ZColors.onDarkSecondary,
      outline: ZColors.divider,
      outlineVariant: isLight ? ZColors.divider : ZColors.darkOutline,
      shadow: ZColors.dark,
      scrim: ZColors.scrim,
      inverseSurface: isLight ? ZColors.dark : ZColors.surface,
      onInverseSurface: isLight ? ZColors.onDark : ZColors.dark,
      inversePrimary: ZColors.primaryTint,
      surfaceContainerHighest:
          isLight ? ZColors.skeleton : ZColors.darkRaised,
      surfaceContainerLow:
          isLight ? ZColors.surface : ZColors.darkRaised,
    );

    // Built manually: google_fonts' interTextTheme returns the extracted
    // material_ui package's TextTheme, which is a distinct type from
    // flutter/material's TextTheme.
    final textTheme = TextTheme(
      displayLarge: ZTypography.display,
      displayMedium: ZTypography.titleLg,
      headlineMedium: ZTypography.titleLg,
      titleLarge: ZTypography.titleLg,
      titleMedium: ZTypography.titleMd,
      titleSmall: ZTypography.captionStrong,
      bodyLarge: ZTypography.body,
      bodyMedium: ZTypography.body,
      bodySmall: ZTypography.caption,
      labelLarge: ZTypography.bodyStrong,
      labelMedium: ZTypography.captionStrong,
      labelSmall: ZTypography.overline,
    ).apply(
      bodyColor: isLight ? ZColors.textPrimary : ZColors.onDark,
      displayColor: isLight ? ZColors.textPrimary : ZColors.onDark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isLight ? ZColors.background : ZColors.dark,
      textTheme: textTheme,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? ZColors.background : ZColors.dark,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: ZTypography.titleMd.copyWith(color: colorScheme.onSurface),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.lg),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZColors.primary,
          foregroundColor: ZColors.onPrimary,
          disabledBackgroundColor: ZColors.disabled,
          disabledForegroundColor: ZColors.textSecondary,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: ZSpacing.xxl,
            vertical: ZSpacing.lg,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZRadii.md),
          ),
          textStyle: ZTypography.bodyStrong,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ZColors.primary,
          foregroundColor: ZColors.onPrimary,
          disabledBackgroundColor: ZColors.disabled,
          disabledForegroundColor: ZColors.textSecondary,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZRadii.md),
          ),
          textStyle: ZTypography.bodyStrong,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ZColors.primary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: ZColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZRadii.md),
          ),
          textStyle: ZTypography.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ZColors.primary,
          textStyle: ZTypography.bodyStrong,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? ZColors.surface : ZColors.darkRaised,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.lg,
          vertical: ZSpacing.lg,
        ),
        hintStyle: ZTypography.body.copyWith(color: ZColors.textTertiary),
        labelStyle: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        floatingLabelStyle: ZTypography.caption.copyWith(color: ZColors.primary),
        border: _inputBorder(colorScheme.outlineVariant),
        enabledBorder: _inputBorder(colorScheme.outlineVariant),
        focusedBorder: _inputBorder(ZColors.primary, width: 1.5),
        errorBorder: _inputBorder(ZColors.error),
        focusedErrorBorder: _inputBorder(ZColors.error, width: 1.5),
        errorStyle: ZTypography.caption.copyWith(color: ZColors.error),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface,
        selectedColor: ZColors.dark,
        labelStyle: ZTypography.caption.copyWith(color: ZColors.textSecondary),
        secondaryLabelStyle: ZTypography.caption.copyWith(color: ZColors.onDark),
        side: const BorderSide(color: ZColors.divider),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.pill),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: ZSpacing.lg,
          vertical: ZSpacing.sm,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(ZRadii.xl)),
        ),
        showDragHandle: true,
        dragHandleColor: ZColors.disabled,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: ZColors.textPrimary,
        unselectedLabelColor: ZColors.textSecondary,
        labelStyle: ZTypography.bodyStrong,
        unselectedLabelStyle: ZTypography.body,
        indicatorColor: ZColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ZColors.dark,
        contentTextStyle: ZTypography.body.copyWith(color: ZColors.onDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZRadii.md),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZColors.onPrimary
              : ZColors.surface,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ZColors.primary
              : ZColors.disabled,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZColors.primary,
        linearTrackColor: ZColors.accent,
      ),
      pageTransitionsTheme: zPageTransitionsTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZRadii.md),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
