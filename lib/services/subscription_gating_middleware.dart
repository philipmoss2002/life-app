import 'package:amplify_flutter/amplify_flutter.dart';
import 'subscription_service.dart';
import 'log_service.dart' as log_svc;

/// Middleware component that enforces subscription requirements for cloud sync operations.
///
/// This component intercepts sync operations and determines whether they should proceed
/// based on the user's subscription status. It provides consistent gating logic across
/// all services that perform cloud synchronization.
///
/// Key responsibilities:
/// - Check subscription status before cloud operations
/// - Provide denial reasons for logging
/// - Execute operations with proper gating logic
/// - Maintain comprehensive logging for all decisions
class SubscriptionGatingMiddleware {
  final SubscriptionService _subscriptionService;
  final _logService = log_svc.LogService();

  /// Last denial reason (for logging purposes)
  String? _lastDenialReason;

  SubscriptionGatingMiddleware(this._subscriptionService);

  /// Check if cloud sync operations are allowed for the current user.
  ///
  /// **Purpose:**
  /// - Determine if user has permission to perform cloud sync operations
  /// - Enforce subscription requirements for cloud features
  /// - Provide consistent gating logic across all services
  ///
  /// **Behavior:**
  /// - Queries subscription service for current status
  /// - Uses cached subscription status (5-minute TTL)
  /// - Logs all decisions for monitoring and debugging
  /// - Stores denial reason for later retrieval
  ///
  /// **Error Handling:**
  /// - On subscription check failure, fails safe to deny cloud sync
  /// - Logs all errors with detailed context
  /// - Provides detailed denial reasons via getDenialReason()
  /// - Never throws exceptions (returns false on error)
  ///
  /// **Performance:**
  /// - Cache hit: <1ms (typical case)
  /// - Cache miss: ~1000ms (once per 5 minutes)
  /// - No blocking operations
  ///
  /// **Returns:**
  /// - `true` if user has an active subscription (cloud sync allowed)
  /// - `false` if user has no subscription or on error (cloud sync denied)
  ///
  /// **Example:**
  /// ```dart
  /// final canSync = await middleware.canPerformCloudSync();
  /// if (canSync) {
  ///   await uploadToCloud(document);
  /// } else {
  ///   safePrint('Sync denied: ${middleware.getDenialReason()}');
  ///   await saveLocally(document);
  /// }
  /// ```
  Future<bool> canPerformCloudSync() async {
    try {
      safePrint(
          'SubscriptionGatingMiddleware: Checking if cloud sync is allowed');

      final hasSubscription =
          await _subscriptionService.hasActiveSubscription();

      if (hasSubscription) {
        safePrint(
            'SubscriptionGatingMiddleware: Cloud sync allowed - active subscription');
        _lastDenialReason = null;

        // Log allowed decision
        _logService.logAuditEvent(
          eventType: 'sync_gating',
          action: 'check_permission',
          outcome: 'allowed',
          details: 'Active subscription - cloud sync allowed',
        );

        return true;
      } else {
        try {
          final status = await _subscriptionService.getSubscriptionStatus();
          _lastDenialReason =
              'Cloud sync denied - subscription status: $status';
        } catch (e) {
          _lastDenialReason =
              'Cloud sync denied - unable to determine subscription status: $e';
        }
        safePrint('SubscriptionGatingMiddleware: $_lastDenialReason');

        // Log denied decision
        _logService.logAuditEvent(
          eventType: 'sync_gating',
          action: 'check_permission',
          outcome: 'denied',
          details: _lastDenialReason!,
        );

        return false;
      }
    } catch (e) {
      // On error, fail-safe to deny cloud sync
      _lastDenialReason = 'Cloud sync denied - error checking subscription: $e';
      safePrint('SubscriptionGatingMiddleware: $_lastDenialReason');
      safePrint(
          'SubscriptionGatingMiddleware: Failing safe to deny cloud sync due to error');

      // Log error and denial
      _logService.log(
        'Gating check error: $e. Failing safe to deny sync.',
        level: log_svc.LogLevel.error,
      );

      _logService.logAuditEvent(
        eventType: 'sync_gating',
        action: 'check_permission',
        outcome: 'denied',
        details: _lastDenialReason!,
      );

      return false;
    }
  }

  /// Get the reason why cloud sync was denied.
  ///
  /// This method returns a human-readable string explaining why the last
  /// cloud sync check was denied. It's useful for logging and debugging.
  ///
  /// Returns the denial reason, or a default message if sync was allowed
  /// or no check has been performed yet.
  String getDenialReason() {
    return _lastDenialReason ?? 'No denial - cloud sync is allowed';
  }

  /// Execute an operation with subscription gating logic.
  ///
  /// **Purpose:**
  /// - Provide a unified way to execute operations with subscription checking
  /// - Automatically route to cloud or local operation based on subscription
  /// - Ensure consistent gating behavior across all services
  ///
  /// **Behavior:**
  /// - Checks subscription status via canPerformCloudSync()
  /// - Executes cloudOperation if subscription is active
  /// - Executes localOperation if subscription is not active
  /// - Logs operation type and reason for monitoring
  ///
  /// **Error Handling:**
  /// - On subscription check failure, executes local operation (fail-safe)
  /// - Logs all errors with detailed context
  /// - Propagates operation errors to caller
  /// - Never blocks local operations
  ///
  /// **Type Safety:**
  /// - Generic type parameter T ensures type safety
  /// - Both operations must return same type
  /// - Compiler enforces return type consistency
  ///
  /// **Performance:**
  /// - Subscription check: <1ms (cached) or ~1000ms (platform query)
  /// - Operation execution: depends on operation
  /// - No additional overhead beyond subscription check
  ///
  /// **Parameters:**
  /// - `cloudOperation`: Operation to execute if user has active subscription
  ///   - Should perform cloud sync (upload, download, delete)
  ///   - May throw exceptions on failure
  /// - `localOperation`: Operation to execute if user has no subscription
  ///   - Should perform local-only operation
  ///   - Should not throw exceptions (fail-safe)
  ///
  /// **Returns:**
  /// - Result of whichever operation was executed (cloud or local)
  /// - Type matches the generic type parameter T
  ///
  /// **Example:**
  /// ```dart
  /// final result = await middleware.executeWithGating<SyncResult>(
  ///   cloudOperation: () async {
  ///     // Upload document to S3
  ///     await s3.upload(document);
  ///     // Update DynamoDB
  ///     await dynamodb.update(document);
  ///     return SyncResult.success();
  ///   },
  ///   localOperation: () async {
  ///     // Save to local database only
  ///     await database.save(document);
  ///     return SyncResult.localOnly();
  ///   },
  /// );
  /// ```
  Future<T> executeWithGating<T>({
    required Future<T> Function() cloudOperation,
    required Future<T> Function() localOperation,
  }) async {
    safePrint('SubscriptionGatingMiddleware: Executing operation with gating');

    bool canSync = false;
    try {
      canSync = await canPerformCloudSync();
    } catch (e) {
      safePrint(
          'SubscriptionGatingMiddleware: Error checking sync permission: $e');
      safePrint(
          'SubscriptionGatingMiddleware: Failing safe to local-only operation');
      canSync = false;
    }

    if (canSync) {
      safePrint('SubscriptionGatingMiddleware: Executing cloud operation');
      try {
        return await cloudOperation();
      } catch (e) {
        safePrint('SubscriptionGatingMiddleware: Cloud operation failed: $e');
        safePrint(
            'SubscriptionGatingMiddleware: Error details - Type: ${e.runtimeType}, Message: $e');
        rethrow;
      }
    } else {
      safePrint('SubscriptionGatingMiddleware: Executing local-only operation');
      safePrint('SubscriptionGatingMiddleware: Reason: ${getDenialReason()}');
      try {
        return await localOperation();
      } catch (e) {
        safePrint('SubscriptionGatingMiddleware: Local operation failed: $e');
        safePrint(
            'SubscriptionGatingMiddleware: Error details - Type: ${e.runtimeType}, Message: $e');
        rethrow;
      }
    }
  }
}
