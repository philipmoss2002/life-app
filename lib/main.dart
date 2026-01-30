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

  // Initialize Amplify in the background (non-blocking)
  // Database will be initialized after authentication check
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
  String _loadingMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  /// Initialize app with proper database setup based on authentication status
  ///
  /// This method:
  /// 1. Checks authentication status
  /// 2. Initializes database for authenticated users
  /// 3. Initializes guest database for unauthenticated users
  /// 4. Handles errors gracefully
  ///
  /// Requirements: 1.1, 6.1
  Future<void> _initializeApp() async {
    try {
      setState(() {
        _loadingMessage = 'Checking authentication...';
      });

      // Check authentication status
      final isAuth = await _authService.isAuthenticated();

      if (isAuth) {
        // User is authenticated - initialize their database
        setState(() {
          _loadingMessage = 'Loading your data...';
        });

        try {
          final userId = await _authService.getUserId();

          // Initialize database
          // The database getter will automatically open the correct user's database
          final dbService = NewDatabaseService.instance;
          await dbService.database;

          debugPrint('Database initialized for authenticated user: $userId');
        } catch (e) {
          debugPrint('Error initializing user database: $e');
          // Don't fail - user can still proceed, database will retry on next operation
        }
      } else {
        // User is not authenticated - initialize guest database
        setState(() {
          _loadingMessage = 'Starting in guest mode...';
        });

        try {
          // Initialize guest database
          await NewDatabaseService.instance.database;
          debugPrint('Guest database initialized');
        } catch (e) {
          debugPrint('Error initializing guest database: $e');
          // Don't fail - show error but allow user to proceed
        }
      }

      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      // On error, assume not authenticated and use guest mode
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return _isAuthenticated
        ? const NewDocumentListScreen()
        : const SignInScreen();
  }
}
