import 'package:flutter/foundation.dart';
import '../services/authentication_service.dart';

/// Provider to manage authentication state across the app
class AuthProvider extends ChangeNotifier {
  final AuthenticationService _authService = AuthenticationService();

  AuthState _authState = AuthState.unknown;
  AppUser? _currentUser;

  AuthState get authState => _authState;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _authState == AuthState.authenticated;

  AuthProvider() {
    _initialize();
  }

  /// Initialize the auth provider and check current auth state
  Future<void> _initialize() async {
    // Listen to auth state changes
    _authService.authStateChanges.listen((state) {
      _authState = state;
      if (state == AuthState.unauthenticated) {
        _currentUser = null;
      }
      notifyListeners();
    });

    // Check if user is already authenticated
    await checkAuthStatus();
  }

  /// Check current authentication status
  Future<void> checkAuthStatus() async {
    try {
      final isAuth = await _authService.isAuthenticated();
      if (isAuth) {
        _currentUser = await _authService.getCurrentUser();
        _authState = AuthState.authenticated;
      } else {
        _currentUser = null;
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      _currentUser = null;
      _authState = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    try {
      _currentUser = await _authService.signIn(email, password);
      _authState = AuthState.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Sign in error: $e');
      _authState = AuthState.unauthenticated;
      _currentUser = null;
      notifyListeners();
      rethrow; // Re-throw so the UI can handle the error
    }
  }

  /// Sign up with email and password
  Future<bool> signUp(String email, String password) async {
    try {
      await _authService.signUp(email, password);
      return true;
    } catch (e) {
      debugPrint('Sign up error: $e');
      return false;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _currentUser = null;
      _authState = AuthState.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Sign out error: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _authService.resetPassword(email);
  }

  /// Confirm password reset
  Future<void> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    await _authService.confirmResetPassword(
      email: email,
      newPassword: newPassword,
      confirmationCode: confirmationCode,
    );
  }
}
