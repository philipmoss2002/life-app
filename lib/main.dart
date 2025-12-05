import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
// import 'services/amplify_service.dart'; // Uncomment when ready to use cloud sync

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tz.initializeTimeZones();

  // Initialize database
  await DatabaseService.instance.database;

  // Initialize notifications
  await NotificationService.instance.initialize();

  // TODO: Initialize Amplify for cloud sync (Task 2+)
  // Uncomment the following lines when AWS resources are configured:
  // try {
  //   await AmplifyService().initialize();
  //   debugPrint('Amplify initialized successfully');
  // } catch (e) {
  //   debugPrint('Failed to initialize Amplify: $e');
  //   // App can still work in local-only mode
  // }

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
