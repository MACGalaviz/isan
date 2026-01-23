import 'package:flutter/material.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/screens/home_screen.dart';
import 'package:isan/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/security/key_derivation_service.dart';
import 'package:isan/services/security/session_key_service.dart';
import 'dart:typed_data';

// Global Notifier to manage Theme State
// By default, it follows the system setting
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TEMP master secret (Sprint 1)
  const tempSecret = 'local-development-secret';
  final salt = Uint8List.fromList('local-dev-salt'.codeUnits);
  final key = await KeyDerivationService.instance.deriveKey(
    secret: tempSecret,
    salt: salt,
  );

  SessionKeyService.instance.setKey(key);

  await Supabase.initialize(
    url: 'https://zowjsdugeslczfywrdgm.supabase.co',      
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpvd2pzZHVnZXNsY3pmeXdyZGdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc1NTYwMjksImV4cCI6MjA4MzEzMjAyOX0.zhXNThJ46p1s_8c9KO5ipL8pPJFW1PaAN9obqHcmElw',     
  );

  await DatabaseService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We wrap MaterialApp with ValueListenableBuilder
    // This allows the app to rebuild instantly when themeNotifier changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Isan',
          debugShowCheckedModeBanner: false,
          
          // Theme Configuration
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          
          // The mode is now dynamic based on our notifier
          themeMode: currentMode, 
          
          home: const HomeScreen(),
        );
      },
    );
  }
}
