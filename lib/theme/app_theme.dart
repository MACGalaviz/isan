import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─────────────────────────────
  // COLORS
  // ─────────────────────────────

  static const Color lightBackground = Color(0xFFE5E5EA);
  static const Color darkBackground  = Color(0xFF1C1C1E);

  static const Color primaryLight = Color(0xFF65558F);
  static const Color primaryDark  = Color(0xFFD0BCFF);

  // ─────────────────────────────
  // TEXT THEME
  // ─────────────────────────────

  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    final primary =
        brightness == Brightness.light ? primaryLight : primaryDark;

    return GoogleFonts.interTextTheme(base).copyWith(

      // ─────────────────────────────
      // HEADLINE — Uses PRIMARY
      // ─────────────────────────────

      headlineLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -1,
        color: primary,
      ),

      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        color: primary,
      ),

      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: primary,
      ),

      // ─────────────────────────────
      // TITLE — onSurface
      // ─────────────────────────────

      titleLarge: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),

      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),

      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      // ─────────────────────────────
      // BODY — onSurface / onSurfaceVariant
      // ─────────────────────────────

      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        height: 1.6,
      ),

      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.5,
      ),

      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        height: 1.4,
      ),

      // ─────────────────────────────
      // LABEL — UI / Metadata
      // ─────────────────────────────

      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),

      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }


  // ─────────────────────────────
  // LIGHT THEME
  // ─────────────────────────────

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      scaffoldBackgroundColor: lightBackground,

      colorScheme: const ColorScheme.light(
        primary: primaryLight,
        surfaceContainerHighest: Colors.white,
        onSurface: Colors.black87,
        onSurfaceVariant: Colors.black54,
      ),

      textTheme: _textTheme(Brightness.light),

      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryLight),
        actionsIconTheme: IconThemeData(color: primaryLight),
      ),

      iconTheme: const IconThemeData(color: primaryLight),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
      ),

      inputDecorationTheme: const InputDecorationTheme(
        prefixIconColor: primaryLight,
        suffixIconColor: primaryLight,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.black87,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryLight,
      ),

    );
  }

  // ─────────────────────────────
  // DARK THEME
  // ─────────────────────────────

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: darkBackground,

      colorScheme: const ColorScheme.dark(
        primary: primaryDark,
        surfaceContainerHighest: Color(0xFF2C2C2E),
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white70,
      ),

      textTheme: _textTheme(Brightness.dark),

      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryDark),
        actionsIconTheme: IconThemeData(color: primaryDark),
      ),

      iconTheme: const IconThemeData(color: primaryDark),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: Color(0xFF381E72),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        prefixIconColor: primaryDark,
        suffixIconColor: primaryDark,
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: primaryDark,
        ),

    );
  }
}
