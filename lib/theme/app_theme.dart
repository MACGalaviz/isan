import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // --- COLORS ---
  
  // CHANGED: Darker gray for Light Mode to reduce glare (was 0xFFF2F2F7)
  static const Color _lightBg = Color(0xFFE5E5EA); 
  
  static const Color _darkBg = Color(0xFF1C1C1E);
  
  static const Color _primary = Color(0xFF65558F); // Deep Purple
  static const Color _primaryDark = Color(0xFFD0BCFF); // Pastel Purple for Dark Mode

  // --- LIGHT THEME ---
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lightBg,
      primaryColor: _primary,
      
      // Define global color scheme
      colorScheme: const ColorScheme.light(
        primary: _primary,
        surfaceContainerHighest: Colors.white, // Cards remain White
        onSurfaceVariant: Colors.grey,
      ),
      
      // Typography
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      
      // APP BAR: Apply primary color to icons automatically
      appBarTheme: const AppBarTheme(
        backgroundColor: _lightBg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: _primary), 
        actionsIconTheme: IconThemeData(color: _primary), 
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0, 
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),

      // Input Decoration (Search icon color)
      inputDecorationTheme: const InputDecorationTheme(
        prefixIconColor: _primary, 
      ),
    );
  }

  // --- DARK THEME ---
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkBg,
      primaryColor: _primaryDark,
      
      colorScheme: const ColorScheme.dark(
        primary: _primaryDark,
        surfaceContainerHighest: Color(0xFF2C2C2E),
        onSurfaceVariant: Color(0xFFAEAEB2),
      ),
      
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkBg,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: IconThemeData(color: _primaryDark), 
        actionsIconTheme: IconThemeData(color: _primaryDark),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _primaryDark,
        foregroundColor: const Color(0xFF381E72),
      ),

      inputDecorationTheme: const InputDecorationTheme(
        prefixIconColor: _primaryDark,
      ),
    );
  }
}
