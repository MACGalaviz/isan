import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/screens/home_screen.dart';
import 'package:isan/screens/reset_password_screen.dart';
import 'package:isan/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isan/services/security/key_manager_service.dart';

// Global Notifier to manage Theme State
// By default, it follows the system setting
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

// Navigator key so early auth events (e.g. password recovery) can route
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Pushes the reset screen, retrying each frame until the navigator is ready.
// This survives a passwordRecovery event that fires before the first frame.
void _routeToReset() {
  final nav = navigatorKey.currentState;
  if (nav != null) {
    nav.push(MaterialPageRoute(builder: (_) => const ResetPasswordScreen()));
  } else {
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeToReset());
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // debugPrint still writes in release builds; silence it so the crypto and
  // sync traces never reach a shipped device's log.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Implicit flow so password-recovery links carry the token in the URL and
  // work cross-device (PKCE keeps the verifier per-browser, which breaks
  // "reset on device A, open link on device B").
  await Supabase.initialize(
    url: 'https://zowjsdugeslczfywrdgm.supabase.co',
    anonKey: 'sb_publishable_a9Emq5_G5ZZfDUBEVSAj-A_XM2fxEa-',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  // Route password-recovery links to the reset screen.
  // Subscribed before runApp so we don't miss the early event.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    debugPrint('🔔 Auth event: ${data.event}');
    if (data.event == AuthChangeEvent.passwordRecovery) {
      _routeToReset();
    }
  });

  // 🔐 CRITICAL: Initialize encryption system
  // This will:
  // - Generate LMK on first launch (local mode)
  // - Load existing key on subsequent launches
  // - Determine local vs user mode automatically
  try {
    await KeyManagerService.instance.initialize();
    debugPrint('✅ Encryption system initialized');
  } catch (e) {
    debugPrint('❌ Failed to initialize encryption: $e');
    // App can still run, but encryption won't work
  }

  await DatabaseService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Isan',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,

          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,

          themeMode: currentMode,

          home: const HomeScreen(),
        );
      },
    );
  }
}