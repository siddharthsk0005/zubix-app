import 'package:flutter/material.dart';

/// Black, white, and grey only, matching the mobile app's brand palette.
class AppColors {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const grey700 = Color(0xFF444444);
  static const grey500 = Color(0xFF8A8A8A);
  static const grey300 = Color(0xFFD0D0D0);
}

ThemeData buildAdminTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.black,
    onPrimary: AppColors.white,
    secondary: AppColors.grey700,
    onSecondary: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.black,
    onSurfaceVariant: AppColors.grey700,
    surfaceTint: AppColors.white,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.white,
    surfaceContainer: AppColors.white,
    surfaceContainerHigh: AppColors.white,
    surfaceContainerHighest: AppColors.white,
    secondaryContainer: AppColors.black,
    onSecondaryContainer: AppColors.white,
    outline: AppColors.grey300,
    error: AppColors.black,
    onError: AppColors.white,
  );

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.grey300),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.black,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.black, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.grey300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.black,
        side: const BorderSide(color: AppColors.grey300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
