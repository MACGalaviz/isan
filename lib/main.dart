import 'package:flutter/material.dart';
import 'package:isan/services/database_service.dart';
import 'package:isan/screens/test_screen.dart'; 

void main() async {
  // 1. Ensure Flutter bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize the Database Engine (Isar)
  await DatabaseService().initialize();

  // 3. Run the App
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Isan Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Set the TestScreen as the starting point
      home: const TestScreen(),
    );
  }
}
