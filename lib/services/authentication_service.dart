import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'analytics_service.dart';
import 'auth_token_manager.dart';
import 'realtime_sync_service.dart';

/// Enum representing the authentication state
enum AuthState {
  authenticated,
  unauthenticated,
  unknown,
}

/// Model representing a user
class AppUser {
  final String id;
  final String email;
  final String? displayName;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
  });
}

/// Service to manage user authentication using AWS Cognito
/// Handles sign up, sign in, sign out, password reset, and session management
class AuthenticationService {
  static final AuthenticationService _instance =
      AuthenticationService._internal();
  factory AuthenticationService() => _instance;
  AuthenticationService._internal();

  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthTokenManager _authTokenManager = AuthTokenManager();
  final RealtimeSyncService _realtimeSyncService = RealtimeSyncService();

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  /// Sign up a new user with email and password
  /// Returns the created user on success
  /// Throws an exception if sign up fails
  Future<AppUser> signUp(String email, String password) async {
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

      // Check if email verification is required
      if (!result.isSignUpComplete) {
        safePrint('Sign up requires email verification');
      }

      // Track successful sign up
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.signUp,
        success: true,
      );

      // Get user details after sign up
      final userId = result.userId ?? email;
      return AppUser(
        id: userId,
        email: email,
      );
    } on AuthException catch (e) {
      safePrint('Error signing up: ${e.message}');

      // Track failed sign up
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.signUp,
        success: false,
        errorMessage: e.message,
      );

      rethrow;
    }
  }

  /// Sign in an existing user with email and password
  /// Returns the authenticated user on success
  /// Throws an exception if sign in fails
  Future<AppUser> signIn(String email, String password) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      if (result.isSignedIn) {
        _authStateController.add(AuthState.authenticated);

        // Track successful sign in
        await _analyticsService.trackAuthEvent(
          type: AuthEventType.signIn,
          success: true,
        );

        // Get user attributes
        final user = await _getCurrentUser();
        return user;
      } else {
        throw Exception('Sign in not complete');
      }
    } on AuthException catch (e) {
      safePrint('Error signing in: ${e.message}');
      _authStateController.add(AuthState.unauthenticated);

      // Track failed sign in
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.signIn,
        success: false,
        errorMessage: e.message,
      );

      rethrow;
    }
  }

  /// Sign out the current user
  /// Clears all authentication tokens and stops synchronization
  Future<void> signOut() async {
    try {
      // Stop all sync operations before signing out
      await _realtimeSyncService.handleSignOut();
      await _authTokenManager.handleSignOut();

      // Force global sign out to clear all sessions
      await Amplify.Auth.signOut(
        options: const SignOutOptions(globalSignOut: true),
      );

      _authStateController.add(AuthState.unauthenticated);

      // Track sign out
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.signOut,
        success: true,
      );

      safePrint('User signed out successfully with global sign out');
    } on AuthException catch (e) {
      safePrint('Error signing out: ${e.message}');

      // Even if Amplify sign-out fails, we should still clean up local state
      try {
        await _realtimeSyncService.handleSignOut();
        await _authTokenManager.handleSignOut();
        _authStateController.add(AuthState.unauthenticated);
      } catch (cleanupError) {
        safePrint('Error during sign-out cleanup: $cleanupError');
      }

      // Track failed sign out
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.signOut,
        success: false,
        errorMessage: e.message,
      );

      rethrow;
    }
  }

  /// Reset password for a user
  /// Sends a password reset code to the user's email
  Future<void> resetPassword(String email) async {
    try {
      final result = await Amplify.Auth.resetPassword(
        username: email,
      );

      if (result.isPasswordReset) {
        safePrint('Password reset complete');
      } else {
        safePrint('Password reset requires confirmation');
      }

      // Track password reset
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.passwordReset,
        success: true,
      );
    } on AuthException catch (e) {
      safePrint('Error resetting password: ${e.message}');

      // Track failed password reset
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.passwordReset,
        success: false,
        errorMessage: e.message,
      );

      rethrow;
    }
  }

  /// Confirm password reset with the code sent to email
  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      safePrint('Password reset confirmed');
    } on AuthException catch (e) {
      safePrint('Error confirming password reset: ${e.message}');
      rethrow;
    }
  }

  /// Check if a user is currently authenticated
  Future<bool> isAuthenticated() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } on AuthException catch (e) {
      safePrint('Error checking authentication: ${e.message}');
      return false;
    }
  }

  /// Get the current authentication token
  /// Returns null if not authenticated
  Future<String?> getAuthToken() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;

      if (session.isSignedIn) {
        return session.userPoolTokensResult.value.idToken.raw;
      }
      return null;
    } on AuthException catch (e) {
      safePrint('Error getting auth token: ${e.message}');
      return null;
    }
  }

  /// Get the current authenticated user
  /// Returns null if not authenticated
  Future<AppUser?> getCurrentUser() async {
    try {
      final isAuth = await isAuthenticated();
      if (!isAuth) {
        return null;
      }
      return await _getCurrentUser();
    } catch (e) {
      safePrint('Error getting current user: $e');
      return null;
    }
  }

  /// Internal method to get current user details
  Future<AppUser> _getCurrentUser() async {
    final attributes = await Amplify.Auth.fetchUserAttributes();

    String? email;
    String? userId;

    for (final attribute in attributes) {
      if (attribute.userAttributeKey == AuthUserAttributeKey.email) {
        email = attribute.value;
      } else if (attribute.userAttributeKey == AuthUserAttributeKey.sub) {
        userId = attribute.value;
      }
    }

    return AppUser(
      id: userId ?? '',
      email: email ?? '',
    );
  }

  /// Delete the current user account (GDPR compliance)
  /// This permanently deletes the user from AWS Cognito
  Future<void> deleteUserAccount() async {
    try {
      await Amplify.Auth.deleteUser();
      _authStateController.add(AuthState.unauthenticated);

      // Track account deletion
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.accountDeleted,
        success: true,
      );

      safePrint('User account deleted successfully');
    } on AuthException catch (e) {
      safePrint('Error deleting user account: ${e.message}');

      // Track failed account deletion
      await _analyticsService.trackAuthEvent(
        type: AuthEventType.accountDeleted,
        success: false,
        errorMessage: e.message,
      );

      rethrow;
    }
  }

  /// Force clear all authentication state and sessions
  /// Use this when experiencing session mix-up issues
  Future<void> forceSignOutAndClearState() async {
    try {
      safePrint('Force clearing all authentication state');

      // Clear all local state first
      await _realtimeSyncService.handleSignOut();
      await _authTokenManager.handleSignOut();

      // Force global sign out
      await Amplify.Auth.signOut(
        options: const SignOutOptions(globalSignOut: true),
      );

      // Clear auth state
      _authStateController.add(AuthState.unauthenticated);

      safePrint('Successfully force cleared all authentication state');
    } catch (e) {
      safePrint('Error during force sign out: $e');
      // Still clear local state even if remote sign out fails
      _authStateController.add(AuthState.unauthenticated);
    }
  }

  /// Dispose resources
  void dispose() {
    _authStateController.close();
  }
}
