import 'package:flutter/material.dart';

import 'shared_colors.dart';

class AppTheme {
  static const Color primary = SharedColors.primary;
  static const Color accent = SharedColors.accent;

  static ThemeData get lightTheme {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: const Color(0xFFF2F7FA),
      secondary: accent,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Noto Sans SC',
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF2F7FA),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0.5,
        backgroundColor: Color(0xFFEAF4FA),
        foregroundColor: Color(0xFF0F2D3A),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 1.2,
        color: Colors.white,
        shadowColor: const Color(0xFF0B3A4A).withValues(alpha: 0.08),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.primary.withValues(alpha: 0.2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (Set<WidgetState> states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              );
            }
            return TextStyle(
              color: scheme.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w600,
            );
          },
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.14)),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
