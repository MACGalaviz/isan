import 'package:flutter/material.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/screens/home_screen.dart'; 
import 'package:isan/theme/app_theme.dart';     

// Global Notifier to manage Theme State
// By default, it follows the system setting
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
