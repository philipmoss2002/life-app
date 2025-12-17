import 'package:flutter/foundation.dart';
import '../services/authentication_service.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';
import '../services/analytics_service.dart';
import '../services/offline_sync_queue_service.dart';
import '../services/storage_manager.dart';
import '../services/performance_monitor.dart';
import '../services/cloud_sync_service.dart';
import '../models/sync_state.dart';

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

        // Migrate any documents with placeholder user IDs to this user
        await _migrateDocumentsToCurrentUser();

        // Initialize cloud sync if user is eligible
        await _initializeCloudSyncIfEligible();
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

      // Verify the signed-in user matches the expected email
      if (_currentUser?.email != email) {
        debugPrint(
            'WARNING: User identity mismatch! Expected: $email, Got: ${_currentUser?.email}');
        // Force sign out and clear state if there's a mismatch
        await _authService.forceSignOutAndClearState();
        await _clearAllUserData();
        _currentUser = null;
        _authState = AuthState.unauthenticated;
        notifyListeners();
        throw Exception(
            'User identity verification failed. Please try signing in again.');
      }

      // Reset all services for the new user session
      await _resetAllServicesForNewUser();

      // Migrate any documents with placeholder user IDs to this user
      await _migrateDocumentsToCurrentUser();

      // Initialize and start cloud sync if user has active subscription
      await _initializeCloudSyncIfEligible();

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
      // Clear user-specific data from local database
      if (_currentUser != null) {
        await DatabaseService.instance.clearUserData(_currentUser!.id);
      }

      // Clear all user-specific data from singleton services
      await _clearAllUserData();

      await _authService.forceSignOutAndClearState();
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

  /// Force reset authentication state (for debugging session issues)
  Future<void> forceResetAuthState() async {
    try {
      debugPrint('Force resetting authentication state');
      await _authService.forceSignOutAndClearState();
      await DatabaseService.instance.clearAllData();
      await _clearAllUserData();
      _currentUser = null;
      _authState = AuthState.unauthenticated;
      notifyListeners();
      debugPrint('Authentication state reset complete');
    } catch (e) {
      debugPrint('Error resetting auth state: $e');
    }
  }

  /// Clear all user-specific data from singleton services
  /// This ensures complete user isolation between sessions
  Future<void> _clearAllUserData() async {
    try {
      debugPrint('Clearing all user-specific data from singleton services');

      // Clear subscription state
      SubscriptionService().clearSubscriptionState();

      // Clear analytics data (metrics stored in SharedPreferences)
      await AnalyticsService().clearUserAnalytics();

      // Clear offline sync queue (operations stored in SharedPreferences)
      await OfflineSyncQueueService().clearUserSyncQueue();

      // Clear storage manager cache (user-specific storage data)
      await StorageManager().clearUserStorageData();

      // Clear performance monitor data (user-specific metrics)
      PerformanceMonitor().clearUserPerformanceData();

      // Clear cloud sync settings (sync preferences in SharedPreferences)
      await CloudSyncService().clearUserSyncSettings();

      debugPrint('All user-specific data cleared successfully');
    } catch (e) {
      debugPrint('Error clearing user-specific data: $e');
    }
  }

  /// Reset all services for new user session
  /// This ensures clean state for the new user
  Future<void> _resetAllServicesForNewUser() async {
    try {
      debugPrint('Resetting all services for new user session');

      // Reset subscription service
      SubscriptionService().resetForNewUser();

      // Reset analytics service
      await AnalyticsService().resetForNewUser();

      // Reset offline sync queue service
      await OfflineSyncQueueService().resetForNewUser();

      // Reset storage manager
      await StorageManager().resetForNewUser();

      // Reset performance monitor
      PerformanceMonitor().resetForNewUser();

      // Reset cloud sync service
      await CloudSyncService().resetForNewUser();

      debugPrint('All services reset for new user session');
    } catch (e) {
      debugPrint('Error resetting services for new user: $e');
    }
  }

  /// Initialize and start cloud sync if user is eligible (authenticated + active subscription)
  Future<void> _initializeCloudSyncIfEligible() async {
    try {
      debugPrint('Checking cloud sync eligibility...');

      // Check if user is authenticated
      if (!isAuthenticated || _currentUser == null) {
        debugPrint(
            'User not authenticated, skipping cloud sync initialization');
        return;
      }

      // Check subscription status
      debugPrint('Checking subscription status for cloud sync...');

      // Ensure subscription service is initialized
      final subscriptionService = SubscriptionService();
      try {
        await subscriptionService.initialize();
      } catch (e) {
        debugPrint('Subscription service already initialized or error: $e');
      }

      final subscriptionStatus =
          await subscriptionService.getSubscriptionStatus();
      debugPrint('Subscription status: ${subscriptionStatus.name}');
      if (subscriptionStatus != SubscriptionStatus.active) {
        debugPrint(
            'No active subscription (${subscriptionStatus.name}), skipping cloud sync initialization');
        return;
      }
      debugPrint(
          'Active subscription confirmed, proceeding with cloud sync initialization');

      debugPrint('User is eligible for cloud sync, initializing...');

      // Initialize cloud sync service
      await CloudSyncService().initialize();

      // Start automatic sync
      await CloudSyncService().startSync();

      // Queue any unsynced documents for sync
      await _queueUnsyncedDocuments();

      debugPrint('Cloud sync initialized and started successfully');
    } catch (e) {
      debugPrint('Error initializing cloud sync: $e');
      // Don't throw - app should continue working even if sync fails
    }
  }

  /// Queue any existing unsynced documents for cloud sync
  Future<void> _queueUnsyncedDocuments() async {
    try {
      if (_currentUser == null) return;

      // Get all documents for the current user
      final documents =
          await DatabaseService.instance.getUserDocuments(_currentUser!.id);

      // Filter documents that need syncing
      final unsyncedDocuments = documents.where((doc) {
        final syncState = SyncState.fromJson(doc.syncState);
        return syncState == SyncState.notSynced ||
            syncState == SyncState.pending ||
            syncState == SyncState.error;
      }).toList();

      if (unsyncedDocuments.isNotEmpty) {
        debugPrint(
            'Queueing ${unsyncedDocuments.length} unsynced documents for sync');

        // Queue each document for sync
        for (final document in unsyncedDocuments) {
          await CloudSyncService().queueDocumentSync(
            document,
            SyncOperationType.upload,
          );
        }

        debugPrint(
            'Successfully queued ${unsyncedDocuments.length} documents for sync');
      } else {
        debugPrint('No unsynced documents found');
      }
    } catch (e) {
      debugPrint('Error queueing unsynced documents: $e');
    }
  }

  /// Migrate documents with placeholder user IDs to current user
  /// This fixes documents created before user isolation was implemented
  Future<void> _migrateDocumentsToCurrentUser() async {
    try {
      if (_currentUser == null) return;

      // Check if there are any documents with placeholder user IDs
      final placeholderCount =
          await DatabaseService.instance.getPlaceholderDocumentCount();

      if (placeholderCount > 0) {
        debugPrint(
            'Found $placeholderCount documents with placeholder user IDs, migrating to ${_currentUser!.id}');

        // Migrate documents to current user
        final migratedCount = await DatabaseService.instance
            .migrateDocumentsToUser(_currentUser!.id);

        debugPrint(
            'Successfully migrated $migratedCount documents to current user');
      } else {
        debugPrint('No documents with placeholder user IDs found');
      }
    } catch (e) {
      debugPrint('Error migrating documents to current user: $e');
      // Don't throw - this is not critical for app functionality
    }
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
