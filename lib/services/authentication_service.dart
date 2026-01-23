import 'dart:async';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/auth_state.dart';

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
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
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

  /// Sign out the current user and clear cached credentials
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      _cachedIdentityPoolId = null;

      // Emit auth state change
      _authStateController.add(AuthState(isAuthenticated: false));
    } on AuthException catch (e) {
      throw AuthenticationException('Sign out failed: ${e.message}');
    } catch (e) {
      throw AuthenticationException('Sign out failed: $e');
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
