import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'retry_manager.dart';

/// Exception thrown when authentication token operations fail
class AuthTokenException implements Exception {
  final String message;
  final Object? originalError;

  AuthTokenException(this.message, [this.originalError]);

  @override
  String toString() => 'AuthTokenException: $message';
}

/// Manages authentication tokens with automatic refresh capabilities
class AuthTokenManager {
  static final AuthTokenManager _instance = AuthTokenManager._internal();
  factory AuthTokenManager() => _instance;
  AuthTokenManager._internal();

  final RetryManager _retryManager = RetryManager();
  String? _cachedAccessToken;
  DateTime? _tokenExpiryTime;
  final Duration _tokenRefreshBuffer = const Duration(minutes: 5);

  /// Execute an operation with automatic token refresh on authentication errors
  Future<T> executeWithTokenRefresh<T>(
    Future<T> Function() operation, {
    int maxRefreshAttempts = 2,
  }) async {
    int refreshAttempts = 0;

    while (refreshAttempts <= maxRefreshAttempts) {
      try {
        // Ensure we have a valid token before the operation
        await _ensureValidToken();

        // Execute the operation
        return await operation();
      } catch (error) {
        // Check if this is an authentication error
        if (_isAuthenticationError(error) &&
            refreshAttempts < maxRefreshAttempts) {
          refreshAttempts++;
          safePrint(
              'Authentication error detected (attempt $refreshAttempts/$maxRefreshAttempts), refreshing token: $error');

          try {
            await _refreshTokenWithRetry();
          } catch (refreshError) {
            safePrint('Token refresh failed: $refreshError');

            // If this is the last attempt, throw the refresh error
            if (refreshAttempts >= maxRefreshAttempts) {
              throw AuthTokenException(
                'Failed to refresh authentication token after $maxRefreshAttempts attempts',
                refreshError,
              );
            }
          }
        } else {
          // Not an auth error or max refresh attempts reached
          rethrow;
        }
      }
    }

    // This should never be reached
    throw AuthTokenException('Unexpected error in token refresh flow');
  }

  /// Get current access token, refreshing if necessary
  Future<String> getValidAccessToken() async {
    await _ensureValidToken();

    if (_cachedAccessToken == null) {
      throw AuthTokenException('No valid access token available');
    }

    return _cachedAccessToken!;
  }

  /// Check if the current token is valid and not expired
  Future<bool> isTokenValid() async {
    try {
      if (_cachedAccessToken == null || _tokenExpiryTime == null) {
        return false;
      }

      // Check if token is expired (with buffer)
      final now = DateTime.now();
      final expiryWithBuffer = _tokenExpiryTime!.subtract(_tokenRefreshBuffer);

      if (now.isAfter(expiryWithBuffer)) {
        safePrint('Token is expired or will expire soon');
        return false;
      }

      return true;
    } catch (e) {
      safePrint('Error checking token validity: $e');
      return false;
    }
  }

  /// Force refresh the authentication token
  Future<void> refreshToken() async {
    await _refreshTokenWithRetry();
  }

  /// Clear cached token (useful for sign-out)
  void clearToken() {
    _cachedAccessToken = null;
    _tokenExpiryTime = null;
    safePrint('Authentication token cleared');
  }

  /// Handle user sign-out by clearing all cached tokens and stopping operations
  /// This should be called when the user signs out
  Future<void> handleSignOut() async {
    safePrint('Handling user sign-out - clearing authentication tokens');

    try {
      // Clear cached tokens
      clearToken();

      // Note: We don't call Amplify.Auth.signOut() here because that should be
      // handled by the AuthenticationService. This method just cleans up
      // the token manager's state.

      safePrint('Successfully handled sign-out in AuthTokenManager');
    } catch (e) {
      safePrint('Error handling sign-out in AuthTokenManager: $e');
      // Don't rethrow - we want sign-out to succeed even if cleanup fails
    }
  }

  /// Check if user is currently signed in
  Future<bool> isSignedIn() async {
    try {
      final result = await Amplify.Auth.fetchAuthSession();
      return result.isSignedIn;
    } catch (e) {
      safePrint('Error checking sign-in status: $e');
      return false;
    }
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (e) {
      safePrint('Error getting current user ID: $e');
      return null;
    }
  }

  // Private methods

  /// Ensure we have a valid token, refreshing if necessary
  Future<void> _ensureValidToken() async {
    if (!await isTokenValid()) {
      await _refreshTokenWithRetry();
    }
  }

  /// Refresh token with retry logic
  Future<void> _refreshTokenWithRetry() async {
    return await _retryManager.executeWithRetry(
      () async => await _refreshTokenInternal(),
      config: RetryManager.authRetryConfig,
      shouldRetry: (error) {
        // Don't retry if user is not signed in
        final errorString = error.toString().toLowerCase();
        if (errorString.contains('not signed in') ||
            errorString.contains('user not found') ||
            errorString.contains('invalid refresh token')) {
          return false;
        }
        return true; // Use default retry logic for other errors
      },
    );
  }

  /// Internal token refresh implementation
  Future<void> _refreshTokenInternal() async {
    try {
      // Check if user is signed in
      if (!await isSignedIn()) {
        throw AuthTokenException('User is not signed in');
      }

      // Fetch new auth session
      final authSession = await Amplify.Auth.fetchAuthSession();

      if (!authSession.isSignedIn) {
        throw AuthTokenException('User session is not valid');
      }

      // Get the access token
      if (authSession is CognitoAuthSession) {
        final accessToken = authSession.userPoolTokensResult.value.accessToken;
        _cachedAccessToken = accessToken.raw;

        // Calculate expiry time from token (use a default expiry if not available)
        _tokenExpiryTime = DateTime.now().add(const Duration(hours: 1));

        safePrint(
            'Authentication token refreshed successfully, expires at: $_tokenExpiryTime');
      } else {
        throw AuthTokenException('Unexpected auth session type');
      }
    } catch (e) {
      _cachedAccessToken = null;
      _tokenExpiryTime = null;

      if (e is AuthTokenException) {
        rethrow;
      } else {
        throw AuthTokenException('Failed to refresh authentication token', e);
      }
    }
  }

  /// Check if an error is authentication-related
  bool _isAuthenticationError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('unauthorized') ||
        errorString.contains('authentication') ||
        errorString.contains('token') ||
        errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('invalid credentials') ||
        errorString.contains('access denied') ||
        errorString.contains('expired');
  }

  /// Get authorization headers for API requests
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getValidAccessToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Get authorization headers with additional custom headers
  Future<Map<String, String>> getAuthHeadersWithCustom(
      Map<String, String> customHeaders) async {
    final authHeaders = await getAuthHeaders();
    return {...authHeaders, ...customHeaders};
  }

  /// Validate that headers contain proper authorization
  bool validateAuthHeaders(Map<String, String> headers) {
    if (!headers.containsKey('Authorization')) {
      return false;
    }

    final authHeader = headers['Authorization'];
    if (authHeader == null || !authHeader.startsWith('Bearer ')) {
      return false;
    }

    // Check that the token part is not empty
    final token = authHeader.substring(7); // Remove 'Bearer ' prefix
    return token.isNotEmpty;
  }

  /// Add authorization headers to existing headers map
  Future<Map<String, String>> addAuthToHeaders(
      Map<String, String> existingHeaders) async {
    final authHeaders = await getAuthHeaders();
    return {...existingHeaders, ...authHeaders};
  }

  /// Execute an operation with proper authorization headers
  Future<T> executeWithAuth<T>(
    Future<T> Function(Map<String, String> headers) operation,
  ) async {
    return await executeWithTokenRefresh(() async {
      final headers = await getAuthHeaders();
      return await operation(headers);
    });
  }

  /// Validate that the current token is valid before performing operations
  /// Throws AuthTokenException if token is invalid or user is not signed in
  Future<void> validateTokenBeforeOperation() async {
    if (!await isSignedIn()) {
      throw AuthTokenException('User is not signed in');
    }

    if (!await isTokenValid()) {
      // Try to refresh the token
      try {
        await refreshToken();
      } catch (e) {
        throw AuthTokenException(
          'Unable to obtain valid authentication token',
          e,
        );
      }
    }

    // Ensure we have a valid token after refresh
    if (_cachedAccessToken == null) {
      throw AuthTokenException('No valid access token available after refresh');
    }
  }

  /// Get user ID from current token
  /// Returns null if not authenticated or token is invalid
  Future<String?> getUserIdFromToken() async {
    try {
      if (!await isSignedIn()) {
        return null;
      }

      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (e) {
      safePrint('Error getting user ID from token: $e');
      return null;
    }
  }

  /// Check if the current session has the required permissions
  /// This validates that the user has an active, authenticated session
  Future<bool> hasValidSession() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      return session.isSignedIn;
    } catch (e) {
      safePrint('Error checking session validity: $e');
      return false;
    }
  }

  /// Public method for testing authentication error classification
  bool isAuthenticationError(Object error) => _isAuthenticationError(error);
}
