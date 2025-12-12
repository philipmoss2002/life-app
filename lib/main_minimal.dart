import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

/// Minimal main.dart for testing - skips all initialization
/// Use this to verify the app can start without any services
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Starting app with minimal initialization');

  runApp(const HouseholdDocsApp());
}

class HouseholdDocsApp extends StatelessWidget {
  const HouseholdDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Household Docs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
