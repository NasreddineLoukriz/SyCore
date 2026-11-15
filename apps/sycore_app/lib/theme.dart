import 'package:flutter/material.dart';

/// A dark, quiet surface: the interface should look like an instrument panel,
/// not like a chat app. Colour is reserved for state (verified, refused).
abstract final class SyTheme {
  static const bg = Color(0xFF0B0F14);
  static const surface = Color(0xFF121821);
  static const surfaceAlt = Color(0xFF182130);
  static const line = Color(0xFF243244);
  static const text = Color(0xFFE6EDF6);
  static const muted = Color(0xFF8FA3BC);
  static const accent = Color(0xFF4DD4C6);
  static const accentDim = Color(0xFF1E6E68);
  static const warn = Color(0xFFE8B45C);
  static const danger = Color(0xFFE5695F);
  static const ok = Color(0xFF62C98A);
  static const violet = Color(0xFF8E8CF0);

  static ThemeData build() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        secondary: violet,
        surface: surface,
        error: danger,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: text,
        displayColor: text,
        fontFamily: 'Inter',
      ),
      dividerColor: line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: const TextStyle(color: muted),
        labelStyle: const TextStyle(color: muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: const Color(0xFF06231F),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: surfaceAlt),
        textStyle: TextStyle(color: text, fontSize: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceAlt,
        contentTextStyle: TextStyle(color: text),
        behavior: SnackBarBehavior.floating,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(line),
        thickness: WidgetStateProperty.all(8),
      ),
    );
  }

  static TextStyle mono([double size = 12.5, Color color = muted]) =>
      TextStyle(fontFamily: 'monospace', fontSize: size, color: color, height: 1.45);

  static TextStyle h1 = const TextStyle(
      fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static TextStyle h2 = const TextStyle(
      fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1);
  static TextStyle body = const TextStyle(fontSize: 13.5, height: 1.5);
  static TextStyle small = const TextStyle(fontSize: 12, color: muted);
}
