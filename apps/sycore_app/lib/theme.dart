import 'package:flutter/material.dart';

/// A quiet, paper-like surface: warm off-white, ink text, one pine accent.
///
/// No glows, no gradients, no neon. Borders are hairlines, corners are small,
/// and colour is reserved for meaning (verified / refused / removed).
abstract final class SyTheme {
  // ── surfaces ──────────────────────────────────────────────────
  static const paper = Color(0xFFF6F2EA);
  static const raised = Color(0xFFFBF8F2);
  static const inset = Color(0xFFEFE9DD);
  static const line = Color(0xFFE1D9C9);
  static const lineSoft = Color(0xFFECE6D8);

  // ── ink ───────────────────────────────────────────────────────
  static const ink = Color(0xFF201D18);
  static const inkSoft = Color(0xFF423C33);
  static const muted = Color(0xFF776F62);
  static const faint = Color(0xFFA9A093);

  // ── meaning ───────────────────────────────────────────────────
  static const accent = Color(0xFF35564A);
  static const accentSoft = Color(0xFFE7EDE6);
  static const ok = Color(0xFF3F6349);
  static const okSoft = Color(0xFFE8EEE6);
  static const danger = Color(0xFF93483B);
  static const dangerSoft = Color(0xFFF7E9E5);
  static const warn = Color(0xFF8A6524);
  static const warnSoft = Color(0xFFF5EDDC);

  // ── people ────────────────────────────────────────────────────
  static const roleAli = accent;
  static const roleSara = Color(0xFF4C5C7A);
  static const roleMona = Color(0xFF8A6524);

  static const _fallback = <String>['Naskh', 'DejaVu Sans'];

  static const radius = 6.0;

  /// Heading face: a book serif; Arabic falls back to Naskh, weight for weight.
  static TextStyle display(double size,
          {FontWeight weight = FontWeight.w400,
          double height = 1.2,
          Color color = ink}) =>
      TextStyle(
        fontFamily: 'Libertine',
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: height,
        fontWeight: weight,
        color: color,
      );

  /// Reading face: a humanist sans; Arabic falls back to Naskh.
  static TextStyle text(double size,
          {FontWeight weight = FontWeight.w400,
          double height = 1.6,
          Color color = ink}) =>
      TextStyle(
        fontFamily: 'Lato',
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: height,
        fontWeight: weight,
        color: color,
      );

  /// Identifiers and key material only.
  static TextStyle mono([double size = 12.5, Color color = inkSoft]) => TextStyle(
        fontFamily: 'Hack',
        fontFamilyFallback: _fallback,
        fontSize: size,
        height: 1.55,
        color: color,
      );

  /// Arabic needs a little more size and a lot more leading to breathe.
  static TextTheme textTheme({required bool ar}) {
    final bump = ar ? 1.0 : 0.0;
    final lead = ar ? 1.18 : 0.0;
    return TextTheme(
      displayLarge: display(ar ? 31 : 35, height: 1.22),
      headlineLarge: display(ar ? 23 : 25, weight: FontWeight.w700, height: 1.28),
      headlineSmall: display(ar ? 17.5 : 18.5,
          weight: FontWeight.w700, height: 1.3),
      titleMedium: text(13.5 + bump, weight: FontWeight.w700, height: 1.45),
      titleSmall: text(12 + bump, weight: FontWeight.w700, height: 1.4),
      bodyLarge: text(14.5 + bump, height: 1.68 + lead),
      bodyMedium: text(13.5 + bump, height: 1.65 + lead),
      bodySmall: text(12 + bump, height: 1.6 + lead, color: muted),
      labelLarge: text(13 + bump, weight: FontWeight.w700, height: 1.3),
      labelMedium: text(11.5 + bump, weight: FontWeight.w700, height: 1.3,
          color: muted),
      labelSmall: text(10.5 + bump, weight: FontWeight.w700, height: 1.35,
          color: faint),
    );
  }

  static ThemeData build({required bool ar}) {
    final base = ThemeData.light(useMaterial3: true);
    final tx = textTheme(ar: ar);

    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c, width: w),
        );

    return base.copyWith(
      scaffoldBackgroundColor: paper,
      canvasColor: paper,
      colorScheme: const ColorScheme.light(
        primary: accent,
        onPrimary: paper,
        secondary: inkSoft,
        onSecondary: paper,
        surface: paper,
        onSurface: ink,
        error: danger,
        onError: paper,
        outline: line,
      ),
      textTheme: tx,
      dividerTheme: const DividerThemeData(
        color: line,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: muted, size: 18),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        hintStyle: tx.bodySmall,
        labelStyle: tx.bodySmall,
        floatingLabelStyle: tx.labelSmall?.copyWith(color: muted),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        border: border(line),
        enabledBorder: border(line),
        focusedBorder: border(accent, 1.2),
        errorBorder: border(danger),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: paper,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle: tx.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: const BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle: tx.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius)),
          textStyle: tx.labelLarge?.copyWith(fontWeight: FontWeight.w400),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: line),
        ),
        titleTextStyle: tx.headlineSmall,
        contentTextStyle: tx.bodyMedium,
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: faint),
        fillColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? accent : null),
        checkColor: const WidgetStatePropertyAll(paper),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        contentTextStyle: tx.bodyMedium?.copyWith(color: paper),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: tx.bodySmall?.copyWith(color: paper),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearMinHeight: 1.5,
        linearTrackColor: lineSoft,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(line),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: line),
        ),
        textStyle: tx.bodyMedium,
      ),
    );
  }
}
