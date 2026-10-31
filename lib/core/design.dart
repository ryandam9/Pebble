import 'package:flutter/material.dart';

import 'pebble_typography.dart';

/// Visual tokens transcribed from docs/mockups/*.svg.
abstract final class PebbleColors {
  static const canvas = Color(0xFFF4F7FC);
  static const ink = Color(0xFF182238);
  static const muted = Color(0xFF728099);
  static const blue = Color(0xFF287CF5);
  static const green = Color(0xFF0D9A71);
  static const purple = Color(0xFF8159DF);
  static const orange = Color(0xFFE6A33E);
  static const stroke = Color(0xFFE8EEF5);
  static const mint = Color(0xFFDDF9EC);
  static const paleBlue = Color(0xFFEAF2FF);
}

const pebbleShadow = [
  BoxShadow(color: Color(0x12334A68), blurRadius: 18, offset: Offset(0, 5)),
];

class PebbleCard extends StatelessWidget {
  const PebbleCard({required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(18), this.onTap, super.key});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: pebbleShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class PebbleButton extends StatelessWidget {
  const PebbleButton({required this.label, required this.onPressed, this.icon, this.purple = false, super.key});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool purple;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: purple
            ? [const Color(0xFF6B4CE4), const Color(0xFF9781F5)]
            : [const Color(0xFF2387F6), const Color(0xFF3DA1FF)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: pebbleShadow,
      ),
      child: SizedBox(
        height: 54,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.check, color: Colors.white),
          label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

ThemeData pebbleTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: PebbleColors.blue, surface: PebbleColors.canvas);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: PebbleColors.canvas,
    fontFamily: PebbleTypography.body,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontFamily: PebbleTypography.editorial, fontSize: 31, fontWeight: FontWeight.w700, color: PebbleColors.ink),
      headlineSmall: TextStyle(fontFamily: PebbleTypography.editorial, fontSize: 23, fontWeight: FontWeight.w600, color: PebbleColors.ink),
      titleLarge: TextStyle(fontFamily: PebbleTypography.editorial, fontSize: 19, fontWeight: FontWeight.w600, color: PebbleColors.ink),
      bodyLarge: TextStyle(fontSize: 15, color: PebbleColors.ink),
      bodyMedium: TextStyle(fontSize: 13, color: PebbleColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PebbleColors.stroke)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PebbleColors.stroke)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PebbleColors.blue, width: 1.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  );
}
