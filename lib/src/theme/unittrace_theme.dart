import 'package:flutter/material.dart';

import 'app_colors.dart';

class UnitTraceTheme {
  UnitTraceTheme._();

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansSC',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.deepEmerald,
        primary: AppColors.deepEmerald,
        secondary: AppColors.brass,
        surface: AppColors.warmSurface,
        error: AppColors.danger,
      ),
      scaffoldBackgroundColor: AppColors.ivory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.ivory,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontFamily: 'NotoSansSC',
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.line),
        ),
      ),
      chipTheme: const ChipThemeData(
        side: BorderSide(color: AppColors.line),
        selectedColor: AppColors.mist,
        checkmarkColor: AppColors.deepEmerald,
        labelStyle: TextStyle(color: AppColors.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deepEmerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepEmerald,
          side: const BorderSide(color: AppColors.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.deepEmerald,
            width: 1.4,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontSize: 24,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AppColors.mutedInk,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(color: AppColors.ink, letterSpacing: 0),
      ),
    );
  }
}
