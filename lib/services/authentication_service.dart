import 'dart:async';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/auth_state.dart';
import 'new_database_service.dart';
import 'log_service.dart' as app_log;

/// Custom exception for authentication errors
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}

/// Service for managing user authentication via AWS Cognito
class AuthenticationService {
  static final AuthenticationService _instance =
      AuthenticationService._internal();
  factory AuthenticationService() => _instance;

  AuthenticationService._internal() {
    _initializeAuthListener();
  }

  String? _cachedIdentityPoolId;
  final _authStateController = StreamController<AuthState>.broadcast();
  StreamSubscription<AuthHubEvent>? _authHubSubscription;
  final _logService = app_log.LogService();

  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream => _authStateController.stream;

  /// Initialize listener for Amplify auth events
  void _initializeAuthListener() {
    _authHubSubscription = Amplify.Hub.listen(HubChannel.Auth, (event) async {
      switch (event.type) {
        case AuthHubEventType.signedIn:
        case AuthHubEventType.signedOut:
        case AuthHubEventType.sessionExpired:
          final authState = await getAuthState();
          _authStateController.add(authState);
          break;
        default:
          break;
      }
    });
  }

  /// Dispose resources
  void dispose() {
    _authHubSubscription?.cancel();
    _authStateController.close();
  }

  /// Sign up a new user with email and password
  Future<AuthResult> signUp(String email, String password) async {
    try {
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            AuthUserAttributeKey.email: email,
          },
        ),
      );

      return AuthResult(
        success: result.isSignUpComplete,
        message: result.isSignUpComplete
            ? 'Sign up successful'
            : 'Please confirm your email',
        needsConfirmation: !result.isSignUpComplete,
      );
    } on AuthException catch (e) {
      throw AuthenticationException('Sign up failed: ${e.message}');
    } catch (e) {
      throw AuthenticationException('Sign up failed: $e');
    }
  }

  /// Sign in an existing user with email and password
  ///
  /// Implements rapid authentication change handling by:
  /// 1. Preparing database for sign-in (ensuring previous database is closed)
  /// 2. Authenticating with AWS Cognito
  /// 3. Initializing user's database
  /// 4. Emitting auth state change
  ///
  /// Requirements: 10.1, 10.4
  Future<AuthResult> signIn(String email, String password) async {
    try {
      // Prepare for sign-in (ensure previous database is closed)
      // Requirements: 10.4
      await NewDatabaseService.instance.prepareForSignIn();

      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        // Get user ID and initialize database
        final userId = await getUserId();
        await _initializeUserDatabase(userId);

        // Cache Identity Pool ID after successful sign in
        await getIdentityPoolId();

        // Emit auth state change
        final authState = await getAuthState();
        _authStateController.add(authState);
      }

      return AuthResult(
        success: result.isSignedIn,
        message:
            result.isSignedIn ? 'Sign in successful' : 'Sign in incomplete',
      );
    } on AuthException catch (e) {
      throw AuthenticationException('Sign in failed: ${e.message}');
    } catch (e) {
      throw AuthenticationException('Sign in failed: $e');
    }
  }

  /// Confirm user sign-up with verification code
  ///
  /// Verifies the user's email address using the 6-digit code sent by AWS Cognito.
  /// Returns an AuthResult indicating successful verification.
  ///
  /// Throws [AuthenticationException] for various error conditions:
  /// - Invalid verification code
  /// - Code has expired
  /// - Too many attempts
  /// - User doesn't exist
  /// - Already verified or other auth issue
  Future<AuthResult> confirmSignUp(
      String email, String confirmationCode) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );

      if (result.isSignUpComplete) {
        return AuthResult(
          success: true,
          message: 'Email verified successfully',
        );
      } else {
        return AuthResult(
          success: false,
          message: 'Verification incomplete',
        );
      }
    } on AuthException catch (e) {
      // Map AWS Cognito errors to user-friendly messages
      final errorMessage = e.message.toLowerCase();

      if (errorMessage.contains('code mismatch') ||
          errorMessage.contains('invalid code')) {
        throw AuthenticationException(
            'Invalid verification code. Please check and try again.');
      } else if (errorMessage.contains('expired')) {
        throw AuthenticationException(
            'Verification code has expired. Please request a new code.');
      } else if (errorMessage.contains('limit exceeded') ||
          errorMessage.contains('too many')) {
        throw AuthenticationException(
            'Too many attempts. Please wait a moment and try again.');
      } else if (errorMessage.contains('user') &&
          errorMessage.contains('not found')) {
        throw AuthenticationException(
            'Account not found. Please sign up again.');
      } else if (errorMessage.contains('not authorized') ||
          errorMessage.contains('already confirmed')) {
        throw AuthenticationException(
            'Account already verified. Please sign in.');
      } else if (errorMessage.contains('network')) {
        throw AuthenticationException(
            'Network error. Please check your connection.');
      } else {
        throw AuthenticationException('Verification failed: ${e.message}');
      }
    } catch (e) {
      throw AuthenticationException('Verification failed. Please try again.');
    }
  }

  /// Resend verification code to user's email
  ///
  /// Requests AWS Cognito to send a new 6-digit verification code to the user's
  /// email address. This is useful when the original code expires or is not received.
  ///
  /// Throws [AuthenticationException] for various error conditions:
  /// - Too many resend attempts
  /// - User doesn't exist
  /// - Already verified
  Future<void> resendSignUpCode(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
    } on AuthException catch (e) {
      // Map AWS Cognito errors to user-friendly messages
      final errorMessage = e.message.toLowerCase();

      if (errorMessage.contains('limit exceeded') ||
          errorMessage.contains('too many')) {
        throw AuthenticationException(
            'Too many resend attempts. Please wait a moment and try again.');
      } else if (errorMessage.contains('user') &&
          errorMessage.contains('not found')) {
        throw AuthenticationException(
            'Account not found. Please sign up again.');
      } else if (errorMessage.contains('not authorized') ||
          errorMessage.contains('already confirmed')) {
        throw AuthenticationException(
            'Account already verified. Please sign in.');
      } else if (errorMessage.contains('network')) {
        throw AuthenticationException(
            'Network error. Please check your connection.');
      } else {
        throw AuthenticationException('Failed to resend code: ${e.message}');
      }
    } catch (e) {
      throw AuthenticationException('Failed to resend code. Please try again.');
    }
  }

  /// Sign out the current user and clear cached credentials
  ///
  /// Implements rapid authentication change handling by:
  /// 1. Preparing database for sign-out (waiting for operations)
  /// 2. Closing database connection
  /// 3. Signing out from AWS Cognito
  /// 4. Emitting auth state change
  ///
  /// Requirements: 10.1, 10.3, 10.4
  Future<void> signOut() async {
    try {
      _logService.log(
        'Starting sign-out process',
        level: app_log.LogLevel.info,
      );

      // Prepare database for sign-out (wait for operations and close)
      // Requirements: 10.3, 10.4
      try {
        await NewDatabaseService.instance.prepareForSignOut();
      } catch (e) {
        // Log error but don't fail sign out if database preparation fails
        _logService.log(
          'Error preparing database for sign out: $e',
          level: app_log.LogLevel.warning,
        );
      }

      // Sign out from AWS Cognito
      await Amplify.Auth.signOut();
      _cachedIdentityPoolId = null;

      // Emit auth state change
      _authStateController.add(AuthState(isAuthenticated: false));

      _logService.log(
        'User signed out successfully',
        level: app_log.LogLevel.info,
      );
    } on AuthException catch (e) {
      throw AuthenticationException('Sign out failed: ${e.message}');
    } catch (e) {
      throw AuthenticationException('Sign out failed: $e');
    }
  }

  /// Initialize database for user
  ///
  /// This method handles the database initialization process for a user:
  /// 1. Opens or creates the user's database
  ///
  /// If database initialization fails, the error is logged but sign-in is
  /// allowed to proceed. This ensures users can still authenticate even if
  /// there are database issues (they can use guest mode).
  ///
  /// Requirements: 1.1, 1.5, 3.1, 3.5
  Future<void> _initializeUserDatabase(String userId) async {
    try {
      _logService.log(
        'Initializing database for user: $userId',
        level: app_log.LogLevel.info,
      );

      final dbService = NewDatabaseService.instance;

      // Trigger database initialization (will open user's database)
      // This call to database getter will automatically open the correct
      // user's database or switch to it if a different database is open
      await dbService.database;

      _logService.log(
        'Database initialized successfully for user: $userId',
        level: app_log.LogLevel.info,
      );
    } catch (e, stackTrace) {
      // Log error but don't throw - allow sign in to proceed even if database init fails
      // User can still use the app in guest mode or retry later
      _logService.log(
        'Failed to initialize database for user $userId: $e\nStack trace: $stackTrace',
        level: app_log.LogLevel.error,
      );

      // Don't throw - allow sign in to proceed
      // The database will be initialized on next operation if this fails
    }
  }

  /// Check if a user is currently authenticated
  Future<bool> isAuthenticated() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      return false;
    }
  }

  /// Get the current authentication state
  Future<AuthState> getAuthState() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (!session.isSignedIn) {
        return AuthState(isAuthenticated: false);
      }

      final userAttributes = await Amplify.Auth.fetchUserAttributes();
      final identityPoolId = await getIdentityPoolId();

      // Extract email from user attributes
      String? userEmail;
      try {
        final emailAttribute = userAttributes.firstWhere(
          (attr) => attr.userAttributeKey.key == 'email',
        );
        userEmail = emailAttribute.value;
      } catch (e) {
        // Email attribute not found
        userEmail = null;
      }

      return AuthState(
        isAuthenticated: true,
        userEmail: userEmail,
        identityPoolId: identityPoolId,
        lastAuthTime: DateTime.now(),
      );
    } catch (e) {
      return AuthState(isAuthenticated: false);
    }
  }

  /// Get the Cognito User Pool user ID (sub claim)
  ///
  /// This is the user's unique identifier in the Cognito User Pool.
  /// Used for AppSync authorization with @auth(identityClaim: "sub")
  Future<String> getUserId() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (!session.isSignedIn) {
        throw AuthenticationException('User is not signed in');
      }

      // Get user attributes to extract sub
      final attributes = await Amplify.Auth.fetchUserAttributes();
      final subAttribute = attributes.firstWhere(
        (attr) => attr.userAttributeKey == AuthUserAttributeKey.sub,
        orElse: () => throw AuthenticationException('User sub claim not found'),
      );

      return subAttribute.value;
    } on AuthException catch (e) {
      throw AuthenticationException('Failed to get user ID: ${e.message}');
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw AuthenticationException('Failed to get user ID: $e');
    }
  }

  /// Get the persistent Identity Pool ID for the current user
  ///
  /// The Identity Pool ID is persistent and tied to the User Pool identity.
  /// It remains constant across app reinstalls when the user signs in.
  Future<String> getIdentityPoolId() async {
    // Return cached value if available
    if (_cachedIdentityPoolId != null) {
      return _cachedIdentityPoolId!;
    }

    try {
      final session = await Amplify.Auth.fetchAuthSession();

      if (!session.isSignedIn) {
        throw AuthenticationException('User is not signed in');
      }

      // Get Identity Pool ID from Cognito session
      if (session is CognitoAuthSession) {
        final identityId = session.identityIdResult.value;

        if (identityId == null || identityId.isEmpty) {
          throw AuthenticationException('Identity Pool ID not available');
        }

        // Validate Identity Pool ID format (should match AWS pattern)
        if (!_isValidIdentityPoolId(identityId)) {
          throw AuthenticationException('Invalid Identity Pool ID format');
        }

        // Cache the Identity Pool ID
        _cachedIdentityPoolId = identityId;
        return identityId;
      }

      throw AuthenticationException('Invalid session type');
    } on AuthException catch (e) {
      throw AuthenticationException(
          'Failed to get Identity Pool ID: ${e.message}');
    } catch (e) {
      if (e is AuthenticationException) rethrow;
      throw AuthenticationException('Failed to get Identity Pool ID: $e');
    }
  }

  /// Validate Identity Pool ID format
  /// Expected format: region:uuid (e.g., us-east-1:12345678-1234-1234-1234-123456789012)
  bool _isValidIdentityPoolId(String identityId) {
    final pattern = RegExp(r'^[a-z]{2}-[a-z]+-\d+:[a-f0-9-]+$');
    return pattern.hasMatch(identityId);
  }

  /// Refresh authentication credentials
  ///
  /// Forces a refresh of the authentication session and Identity Pool ID.
  /// Useful when credentials expire or need to be updated.
  Future<void> refreshCredentials() async {
    try {
      await Amplify.Auth.fetchAuthSession(
        options: const FetchAuthSessionOptions(forceRefresh: true),
      );

      // Refresh cached Identity Pool ID
      _cachedIdentityPoolId = null;
      await getIdentityPoolId();

      // Emit updated auth state
      final authState = await getAuthState();
      _authStateController.add(authState);
    } on AuthException catch (e) {
      throw AuthenticationException(
          'Failed to refresh credentials: ${e.message}');
    } catch (e) {
      throw AuthenticationException('Failed to refresh credentials: $e');
    }
  }
}

/// Result of an authentication operation
class AuthResult {
  final bool success;
  final String message;
  final bool needsConfirmation;

  AuthResult({
    required this.success,
    required this.message,
    this.needsConfirmation = false,
  });
}
