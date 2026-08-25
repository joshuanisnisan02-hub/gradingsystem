import 'package:flutter/material.dart';

abstract final class SmartGradeColors {
  static const black = Color(0xFF17151A);
  static const ink = Color(0xFF262329);
  static const red = Color(0xFFB3262E);
  static const redDark = Color(0xFF811A21);
  static const mustard = Color(0xFFD3A62A);
  static const mustardSoft = Color(0xFFF7EBC7);
  static const canvas = Color(0xFFF6F4F1);
  static const white = Color(0xFFFFFFFF);
  static const line = Color(0xFFE4E0DC);
  static const muted = Color(0xFF787279);
}

ThemeData smartGradeTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SmartGradeColors.red,
    primary: SmartGradeColors.red,
    secondary: SmartGradeColors.mustard,
    surface: SmartGradeColors.white,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: SmartGradeColors.canvas,
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    dividerColor: SmartGradeColors.line,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: SmartGradeColors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: SmartGradeColors.line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SmartGradeColors.white,
      labelStyle: const TextStyle(color: SmartGradeColors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SmartGradeColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SmartGradeColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: SmartGradeColors.red, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SmartGradeColors.red,
        foregroundColor: SmartGradeColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      ),
    ),
  );
}
