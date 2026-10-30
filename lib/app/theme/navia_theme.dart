import 'package:flutter/material.dart';

import 'navia_surfaces.dart';
import 'navia_tokens.dart';

/// Builds the Material 3 themes of Navia from the design tokens.
abstract final class NaviaTheme {
  static ThemeData get light => _build(
    ColorScheme.fromSeed(
      seedColor: NaviaColors.brand,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: NaviaColors.brandDeep,
      onPrimary: Colors.white,
      secondary: NaviaColors.aqua,
      onSecondary: const Color(0xFF00382F),
      surface: NaviaColors.surfaceLight,
      onSurface: NaviaColors.inkLight,
      onSurfaceVariant: NaviaColors.inkLightMuted,
      error: NaviaColors.error,
    ),
    background: NaviaColors.backgroundLight,
    surfaces: NaviaSurfaces.light,
  );

  static ThemeData get dark => _build(
    ColorScheme.fromSeed(
      seedColor: NaviaColors.brand,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: NaviaColors.brandLight,
      onPrimary: const Color(0xFF00214D),
      secondary: NaviaColors.aquaLight,
      onSecondary: const Color(0xFF00382F),
      surface: NaviaColors.surfaceDark,
      surfaceContainerHigh: NaviaColors.surfaceDarkRaised,
      onSurface: NaviaColors.inkDark,
      onSurfaceVariant: NaviaColors.inkDarkMuted,
      error: NaviaColors.errorDark,
    ),
    background: NaviaColors.backgroundDark,
    surfaces: NaviaSurfaces.dark,
  );

  static ThemeData _build(
    ColorScheme scheme, {
    required Color background,
    required NaviaSurfaces surfaces,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    final textTheme = _textTheme(base.textTheme, scheme);

    const buttonShape = RoundedRectangleBorder(borderRadius: NaviaRadii.mdAll);
    const buttonMinSize = Size(64, NaviaSizes.minTouchTarget);
    const buttonPadding = EdgeInsets.symmetric(horizontal: NaviaSpacing.xl);

    return base.copyWith(
      textTheme: textTheme,
      extensions: [surfaces],
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: NaviaRadii.lgAll,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMinSize,
          padding: buttonPadding,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(NaviaSizes.minTouchTarget),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: buttonMinSize,
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: NaviaSpacing.lg),
        minVerticalPadding: NaviaSpacing.md,
        iconColor: scheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(borderRadius: NaviaRadii.mdAll),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NaviaSpacing.lg,
          vertical: NaviaSpacing.md,
        ),
        border: const OutlineInputBorder(
          borderRadius: NaviaRadii.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: NaviaRadii.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: NaviaRadii.lgAll),
        titleTextStyle: textTheme.titleLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(Icons.check, size: 14)
              : null,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: NaviaRadii.mdAll),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NaviaRadii.lg),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.6),
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }

  /// Uses the platform font (Roboto on Android) so no font is downloaded at
  /// runtime, with tighter headings and comfortable body sizes.
  static TextTheme _textTheme(TextTheme base, ColorScheme scheme) {
    return base
        .copyWith(
          headlineSmall: base.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          titleLarge: base.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          labelLarge: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
          bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
