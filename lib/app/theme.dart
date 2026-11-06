import 'package:flutter/material.dart';

ThemeData buildWarehouseTheme() {
  const ink = Color(0xFF0F172A);
  const teal = Color(0xFF0B7A72);
  final scheme = ColorScheme.fromSeed(
    seedColor: teal,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    fontFamily: 'Roboto',
    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        color: ink,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: ink),
      bodyMedium: TextStyle(color: Color(0xFF475569)),
      bodySmall: TextStyle(color: Color(0xFF64748B)),
    ),
    // ponytail: Dam bao vung cham toi thieu 44-48dp cho mobile (touch-targets skill)
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDCE3EB)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: const Color(0xFFE2E8F0),
  );
}
