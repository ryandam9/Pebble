import 'package:flutter/material.dart';

abstract final class PebbleColors {
  static const ink = Color(0xFF182238);
  static const muted = Color(0xFF728099);
  static const background = Color(0xFFF4F7FC);
  static const blue = Color(0xFF287CF5);
  static const green = Color(0xFF0D9A71);
  static const purple = Color(0xFF8159DF);
  static const orange = Color(0xFFE6A33E);
  static const coral = Color(0xFFEF705C);
}

ThemeData pebbleTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PebbleColors.blue,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PebbleColors.background,
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 30, fontWeight: FontWeight.w800, color: PebbleColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w700, color: PebbleColors.ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, color: PebbleColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1E8F1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1E8F1)),
      ),
    ),
  );
}
