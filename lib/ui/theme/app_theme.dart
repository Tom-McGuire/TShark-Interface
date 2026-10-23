import 'package:flutter/material.dart';

class AppTheme {
  static const darkBackground = Color(0xFF0D1117);
  static const surface = Color(0xFF161B22);
  static const cardColor = Color(0xFF1F242C);
  static const borderColor = Color(0xFF30363D);
  static const accentCyan = Color(0xFF38BDF8);
  static const accentEmerald = Color(0xFF10B981);
  static const accentRed = Color(0xFFEF4444);
  static const accentAmber = Color(0xFFF59E0B);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: accentCyan,
        onPrimary: Colors.black,
        secondary: accentEmerald,
        surface: surface,
        error: accentRed,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF13171F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accentCyan, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      fontFamily: 'Segoe UI',
    );
  }
}
