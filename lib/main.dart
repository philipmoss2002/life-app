import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'providers/auth_provider.dart';
import 'services/amplify_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tz.initializeTimeZones();

  // Initialize database
  try {
    await DatabaseService.instance.database;
    debugPrint('Database initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize database: $e');
  }

  // Initialize notifications
  try {
    await NotificationService.instance.initialize();
    debugPrint('Notifications initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize notifications: $e');
  }

  // Initialize subscription service
  _initializeSubscriptionService();

  // Start the app immediately
  runApp(const HouseholdDocsApp());

  // Initialize Amplify in the background (non-blocking)
  _initializeAmplifyInBackground();
}

void _initializeSubscriptionService() {
  Future.delayed(Duration.zero, () async {
    try {
      debugPrint('Initializing subscription service...');
      await SubscriptionService().initialize();
      debugPrint('Subscription service initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize subscription service: $e');
      debugPrint('Subscription features may not work properly');
    }
  });
}

void _initializeAmplifyInBackground() {
  Future.delayed(Duration.zero, () async {
    try {
      await AmplifyService().initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              'Amplify initialization timed out - continuing in local-only mode');
          throw TimeoutException('Amplify initialization timed out');
        },
      );
      debugPrint('Amplify initialized successfully');
    } catch (e) {
      debugPrint('Failed to initialize Amplify: $e');
      debugPrint('App will run in local-only mode');
      // App can still work in local-only mode
    }
  });
}

class HouseholdDocsApp extends StatelessWidget {
  const HouseholdDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Household Docs',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
