import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class FutureMintTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: FutureMintTokens.mint,
      brightness: brightness,
      primary: dark ? const Color(0xFFB8AEFF) : FutureMintTokens.ink,
      onPrimary: dark ? FutureMintTokens.ink : Colors.white,
      primaryContainer: dark
          ? const Color(0xFF393368)
          : FutureMintTokens.mintSoft,
      onPrimaryContainer: dark ? const Color(0xFFFBF9FF) : FutureMintTokens.ink,
      secondary: dark ? const Color(0xFFC3BCFF) : FutureMintTokens.teal,
      onSecondary: dark ? FutureMintTokens.ink : Colors.white,
      secondaryContainer: dark
          ? const Color(0xFF64302C)
          : FutureMintTokens.coralSoft,
      onSecondaryContainer: dark
          ? const Color(0xFFFFF4F2)
          : FutureMintTokens.ink,
      surface: dark ? FutureMintTokens.darkSurface : FutureMintTokens.paper,
      onSurface: dark ? const Color(0xFFFFF8EE) : FutureMintTokens.ink,
      outline: dark ? const Color(0xFFAAA8C0) : FutureMintTokens.outline,
      outlineVariant: dark
          ? const Color(0xFF464459)
          : FutureMintTokens.hairline,
      error: dark ? const Color(0xFFFFB4AB) : FutureMintTokens.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark
          ? FutureMintTokens.darkCanvas
          : FutureMintTokens.canvas,
      visualDensity: VisualDensity.standard,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          height: 1.08,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.7,
          height: 1.12,
          fontSize: 28,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusMedium),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusSmall),
          borderSide: BorderSide(color: scheme.outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusSmall),
          borderSide: BorderSide(color: scheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusSmall),
          borderSide: const BorderSide(color: FutureMintTokens.teal, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: FutureMintTokens.space4,
          vertical: FutureMintTokens.space3,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, FutureMintTokens.controlHeight),
          foregroundColor: dark ? FutureMintTokens.ink : Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: FutureMintTokens.space5,
            vertical: FutureMintTokens.space3,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, FutureMintTokens.controlHeight),
          side: BorderSide(color: scheme.outline, width: 1.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, FutureMintTokens.controlHeight),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.transparent,
        elevation: 0,
        indicatorColor: dark ? FutureMintTokens.lavender : FutureMintTokens.sun,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: dark ? FutureMintTokens.lavender : FutureMintTokens.sun,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        selectedLabelTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (!states.contains(WidgetState.selected)) {
              return Colors.transparent;
            }
            return dark ? FutureMintTokens.mint : FutureMintTokens.mintSoft;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return FutureMintTokens.ink;
            }
            return scheme.onSurface;
          }),
          side: WidgetStateProperty.all(
            BorderSide(color: scheme.outline, width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark
            ? FutureMintTokens.darkSurface
            : FutureMintTokens.paper,
        modalBackgroundColor: dark
            ? FutureMintTokens.darkSurface
            : FutureMintTokens.paper,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark
            ? FutureMintTokens.darkSurfaceRaised
            : FutureMintTokens.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusMedium),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? FutureMintTokens.lavender
            : FutureMintTokens.ink,
        contentTextStyle: TextStyle(
          color: dark ? FutureMintTokens.ink : FutureMintTokens.paper,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FutureMintTokens.radiusSmall),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: dark ? FutureMintTokens.mint : FutureMintTokens.teal,
        linearTrackColor: dark
            ? FutureMintTokens.darkSurfaceRaised
            : FutureMintTokens.mintSoft,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: dark
            ? FutureMintTokens.lavender
            : FutureMintTokens.teal,
        inactiveTrackColor: dark
            ? FutureMintTokens.darkSurfaceRaised
            : FutureMintTokens.sunSoft,
        thumbColor: dark ? FutureMintTokens.sun : FutureMintTokens.coral,
        overlayColor: (dark ? FutureMintTokens.sun : FutureMintTokens.coral)
            .withValues(alpha: .14),
      ),
    );
  }
}
