import 'dart:async';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'screens/sign_in_screen.dart';
import 'screens/new_document_list_screen.dart';
import 'services/new_database_service.dart';
import 'services/authentication_service.dart';
import 'services/amplify_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tz.initializeTimeZones();

  // Initialize database
  try {
    await NewDatabaseService.instance.database;
    debugPrint('Database initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize database: $e');
  }

  // Initialize Amplify in the background (non-blocking)
  _initializeAmplifyInBackground();

  // Start the app
  runApp(const HouseholdDocsApp());
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
    }
  });
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
      home: const AuthenticationWrapper(),
    );
  }
}

class AuthenticationWrapper extends StatefulWidget {
  const AuthenticationWrapper({super.key});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  final AuthenticationService _authService = AuthenticationService();
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAuthenticated
        ? const NewDocumentListScreen()
        : const SignInScreen();
  }
}
