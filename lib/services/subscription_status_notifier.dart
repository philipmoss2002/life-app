import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'subscription_service.dart' as sub;

/// Notifier that listens for subscription status changes and broadcasts them to UI components
/// This component extends ChangeNotifier to integrate with Flutter's reactive UI system
class SubscriptionStatusNotifier extends ChangeNotifier {
  final sub.SubscriptionService _subscriptionService;

  sub.SubscriptionStatus _status = sub.SubscriptionStatus.none;
  DateTime? _expirationDate;
  StreamSubscription<sub.SubscriptionStatus>? _statusSubscription;
  bool _isInitialized = false;

  SubscriptionStatusNotifier(this._subscriptionService);

  /// Current subscription status
  sub.SubscriptionStatus get status => _status;

  /// Expiration date for active subscriptions
  DateTime? get expirationDate => _expirationDate;

  /// Whether cloud sync is enabled based on subscription status
  bool get isCloudSyncEnabled =>
      _status == sub.SubscriptionStatus.active ||
      _status == sub.SubscriptionStatus.gracePeriod;

  /// Whether the notifier has been initialized
  bool get isInitialized => _isInitialized;

  /// Initialize the notifier and start listening for subscription changes
  ///
  /// **Purpose:**
  /// - Set up subscription status monitoring
  /// - Get initial subscription status
  /// - Start listening for status changes
  /// - Enable reactive UI updates
  ///
  /// **Behavior:**
  /// - Queries subscription service for initial status
  /// - Subscribes to subscription status change stream
  /// - Notifies listeners of initial state
  /// - Handles errors in status stream
  ///
  /// **Side Effects:**
  /// - Sets _isInitialized to true
  /// - Creates stream subscription
  /// - Notifies all listeners
  /// - Logs initialization progress
  ///
  /// **Error Handling:**
  /// - Logs errors during initialization
  /// - Rethrows errors to caller
  /// - Handles stream errors gracefully
  ///
  /// **Thread Safety:**
  /// - Checks if already initialized to prevent double initialization
  /// - Safe to call multiple times (no-op if already initialized)
  ///
  /// **Performance:**
  /// - Initial status query: ~1ms (cached) or ~1000ms (platform query)
  /// - Stream subscription: negligible overhead
  /// - Listener notification: depends on number of listeners
  ///
  /// **Example:**
  /// ```dart
  /// final notifier = SubscriptionStatusNotifier(subscriptionService);
  /// await notifier.initialize();
  ///
  /// // Now safe to use in UI
  /// final status = notifier.status;
  /// final canSync = notifier.isCloudSyncEnabled;
  /// ```
  Future<void> initialize() async {
    if (_isInitialized) {
      safePrint('SubscriptionStatusNotifier already initialized');
      return;
    }

    try {
      safePrint('Initializing SubscriptionStatusNotifier...');

      // Initialize the subscription service first
      safePrint('Initializing SubscriptionService...');
      await _subscriptionService.initialize();
      safePrint('SubscriptionService initialized');

      // Get initial subscription status
      _status = await _subscriptionService.getSubscriptionStatus();
      safePrint('Initial subscription status: $_status');

      // Listen for subscription status changes
      _statusSubscription = _subscriptionService.subscriptionChanges.listen(
        _onStatusChanged,
        onError: (error) {
          safePrint('Error in subscription status stream: $error');
        },
      );

      _isInitialized = true;
      safePrint('SubscriptionStatusNotifier initialized successfully');

      // Notify listeners of initial state
      notifyListeners();
    } catch (e) {
      safePrint('Error initializing SubscriptionStatusNotifier: $e');
      rethrow;
    }
  }

  /// Handle subscription status changes
  ///
  /// **Purpose:**
  /// - Process subscription status changes from subscription service
  /// - Update local state with new status
  /// - Notify all UI listeners of the change
  /// - Trigger UI updates across the app
  ///
  /// **Behavior:**
  /// - Stores old status for logging
  /// - Updates current status
  /// - Updates expiration date based on new status
  /// - Notifies all listeners (triggers UI rebuild)
  /// - Logs status transition
  ///
  /// **Status-Specific Behavior:**
  /// - **Active/Grace Period**: Keeps or sets expiration date
  /// - **Expired**: Keeps expiration date (shows when it expired)
  /// - **None**: Clears expiration date
  ///
  /// **UI Impact:**
  /// - All widgets listening to this notifier will rebuild
  /// - Visual indicators update automatically
  /// - Sync status badges update
  /// - Settings screen updates
  ///
  /// **Performance:**
  /// - Minimal overhead (just state update)
  /// - Listener notification: O(n) where n = number of listeners
  /// - UI rebuilds only affected widgets (Flutter optimization)
  ///
  /// **Thread Safety:**
  /// - Called from subscription service stream
  /// - Safe to call from any thread
  /// - notifyListeners() is thread-safe
  ///
  /// **Example Flow:**
  /// ```
  /// User purchases subscription
  ///   ↓
  /// Subscription service detects purchase
  ///   ↓
  /// Broadcasts status change (none → active)
  ///   ↓
  /// _onStatusChanged called
  ///   ↓
  /// Updates _status and _expirationDate
  ///   ↓
  /// Calls notifyListeners()
  ///   ↓
  /// All UI widgets rebuild with new status
  ///   ↓
  /// User sees "Cloud Sync Enabled" indicator
  /// ```
  void _onStatusChanged(sub.SubscriptionStatus newStatus) {
    safePrint('Subscription status changed: $_status -> $newStatus');

    final oldStatus = _status;
    _status = newStatus;

    // Update expiration date if needed
    // Note: In production, this should come from the subscription service
    if (_status == sub.SubscriptionStatus.active ||
        _status == sub.SubscriptionStatus.gracePeriod) {
      // Keep existing expiration date or set a default
      _expirationDate ??= DateTime.now().add(const Duration(days: 30));
    } else if (_status == sub.SubscriptionStatus.expired ||
        _status == sub.SubscriptionStatus.none) {
      // Clear expiration date for expired/none status
      if (_status == sub.SubscriptionStatus.expired) {
        // Keep the expiration date to show when it expired
      } else {
        _expirationDate = null;
      }
    }

    // Notify all listeners (UI components) of the change
    notifyListeners();

    // Log the transition for debugging
    safePrint(
        'Subscription status transition complete: $oldStatus -> $newStatus, cloudSyncEnabled: $isCloudSyncEnabled');
  }

  /// Manually refresh subscription status
  Future<void> refresh() async {
    try {
      safePrint('Manually refreshing subscription status...');
      await _subscriptionService.refreshSubscriptionStatus();
      // Status change will come through the stream
    } catch (e) {
      safePrint('Error refreshing subscription status: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    safePrint('Disposing SubscriptionStatusNotifier');
    _statusSubscription?.cancel();
    super.dispose();
  }
}
