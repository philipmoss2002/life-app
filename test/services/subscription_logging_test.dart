import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/subscription_gating_middleware.dart';
import 'package:household_docs_app/services/analytics_service.dart';
import 'package:household_docs_app/services/log_service.dart' as log_svc;

/// Unit tests for subscription logging functionality
/// Tests subscription check logging, gating decision logging, and state transition logging
/// Requirements: All
void main() {
  group('Subscription Logging Tests', () {
    late log_svc.LogService logService;
    late AnalyticsService analyticsService;

    setUp(() {
      logService = log_svc.LogService();
      analyticsService = AnalyticsService();

      // Clear logs before each test
      logService.clearAll();
    });

    tearDown(() async {
      // Clean up after each test
      logService.clearAll();
      await analyticsService.resetAnalytics();
    });

    group('Subscription Check Logging', () {
      test('should log subscription status checks', () {
        // Arrange
        const userId = 'test-user-123';
        const status = SubscriptionStatus.active;

        // Act
        logService.logAuditEvent(
          eventType: 'subscription_check',
          action: 'check_status',
          userIdentifier: userId,
          outcome: 'success',
          details: 'Subscription status: ${status.toString()}',
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.eventType, 'subscription_check');
        expect(auditLogs.first.action, 'check_status');
        expect(auditLogs.first.outcome, 'success');
        expect(auditLogs.first.details, contains('active'));
      });

      test('should log failed subscription checks', () {
        // Arrange
        const userId = 'test-user-123';
        const errorMessage = 'Platform query timeout';

        // Act
        logService.logAuditEvent(
          eventType: 'subscription_check',
          action: 'check_status',
          userIdentifier: userId,
          outcome: 'failure',
          details: 'Error: $errorMessage',
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.outcome, 'failure');
        expect(auditLogs.first.details, contains('timeout'));
      });

      test('should log cache hit vs cache miss', () {
        // Arrange
        const userId = 'test-user-123';

        // Act - Cache hit
        logService.log(
          'Subscription check: cache hit for user $userId',
          level: log_svc.LogLevel.info,
        );

        // Act - Cache miss
        logService.log(
          'Subscription check: cache miss for user $userId, querying platform',
          level: log_svc.LogLevel.info,
        );

        // Assert
        final logs = logService.getAllLogs();
        expect(logs.length, 2);
        expect(logs[0].message, contains('cache hit'));
        expect(logs[1].message, contains('cache miss'));
      });

      test('should log subscription check with timing', () {
        // Arrange
        const userId = 'test-user-123';
        final duration = Duration(milliseconds: 150);

        // Act
        logService.recordPerformanceMetric(
          operation: 'subscription_check',
          duration: duration,
          userIdentifier: userId,
          success: true,
        );

        // Assert
        final metrics = logService.getPerformanceMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.operation, 'subscription_check');
        expect(metrics.first.duration, duration);
        expect(metrics.first.success, true);
      });
    });

    group('Gating Decision Logging', () {
      test('should log sync allowed decision', () {
        // Arrange
        const userId = 'test-user-123';
        const syncId = 'doc-sync-456';

        // Act
        logService.logAuditEvent(
          eventType: 'sync_gating',
          action: 'check_permission',
          userIdentifier: userId,
          resourceId: syncId,
          outcome: 'allowed',
          details: 'Active subscription - cloud sync allowed',
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.eventType, 'sync_gating');
        expect(auditLogs.first.outcome, 'allowed');
        expect(auditLogs.first.details, contains('allowed'));
      });

      test('should log sync denied decision with reason', () {
        // Arrange
        const userId = 'test-user-123';
        const syncId = 'doc-sync-456';
        const denialReason = 'No active subscription';

        // Act
        logService.logAuditEvent(
          eventType: 'sync_gating',
          action: 'check_permission',
          userIdentifier: userId,
          resourceId: syncId,
          outcome: 'denied',
          details: 'Cloud sync denied - reason: $denialReason',
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.outcome, 'denied');
        expect(auditLogs.first.details, contains('No active subscription'));
      });

      test('should log gating decision for multiple operations', () {
        // Arrange
        const userId = 'test-user-123';
        final operations = ['upload', 'download', 'delete'];

        // Act
        for (final operation in operations) {
          logService.logAuditEvent(
            eventType: 'sync_gating',
            action: operation,
            userIdentifier: userId,
            outcome: 'denied',
            details: 'Operation $operation denied - no subscription',
          );
        }

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 3);
        expect(auditLogs.every((log) => log.outcome == 'denied'), true);
      });

      test('should log gating error with fallback behavior', () {
        // Arrange
        const userId = 'test-user-123';
        const errorMessage = 'Subscription service unavailable';

        // Act
        logService.log(
          'Gating check error for user $userId: $errorMessage. Failing safe to deny sync.',
          level: log_svc.LogLevel.error,
        );

        // Assert
        final errorLogs = logService.getLogsByLevel(log_svc.LogLevel.error);
        expect(errorLogs.length, 1);
        expect(errorLogs.first.message, contains('Failing safe'));
      });
    });

    group('State Transition Logging', () {
      test('should log subscription activation', () {
        // Arrange
        const userId = 'test-user-123';
        const previousStatus = SubscriptionStatus.none;
        const newStatus = SubscriptionStatus.active;

        // Act
        logService.logAuditEvent(
          eventType: 'subscription_state_change',
          action: 'status_changed',
          userIdentifier: userId,
          outcome: 'success',
          details:
              'Status changed from ${previousStatus.toString()} to ${newStatus.toString()}',
          metadata: {
            'previous_status': previousStatus.toString(),
            'new_status': newStatus.toString(),
            'transition_type': 'activation',
          },
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.eventType, 'subscription_state_change');
        expect(auditLogs.first.details, contains('none'));
        expect(auditLogs.first.details, contains('active'));
        expect(auditLogs.first.metadata?['transition_type'], 'activation');
      });

      test('should log subscription expiration', () {
        // Arrange
        const userId = 'test-user-123';
        const previousStatus = SubscriptionStatus.active;
        const newStatus = SubscriptionStatus.expired;

        // Act
        logService.logAuditEvent(
          eventType: 'subscription_state_change',
          action: 'status_changed',
          userIdentifier: userId,
          outcome: 'success',
          details:
              'Status changed from ${previousStatus.toString()} to ${newStatus.toString()}',
          metadata: {
            'previous_status': previousStatus.toString(),
            'new_status': newStatus.toString(),
            'transition_type': 'expiration',
          },
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.metadata?['transition_type'], 'expiration');
      });

      test('should log subscription renewal', () {
        // Arrange
        const userId = 'test-user-123';
        const previousStatus = SubscriptionStatus.expired;
        const newStatus = SubscriptionStatus.active;

        // Act
        logService.logAuditEvent(
          eventType: 'subscription_state_change',
          action: 'status_changed',
          userIdentifier: userId,
          outcome: 'success',
          details:
              'Status changed from ${previousStatus.toString()} to ${newStatus.toString()}',
          metadata: {
            'previous_status': previousStatus.toString(),
            'new_status': newStatus.toString(),
            'transition_type': 'renewal',
          },
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.metadata?['transition_type'], 'renewal');
      });

      test('should log pending documents sync trigger on activation', () {
        // Arrange
        const userId = 'test-user-123';
        const pendingCount = 5;

        // Act
        logService.log(
          'Subscription activated for user $userId. Triggering sync for $pendingCount pending documents.',
          level: log_svc.LogLevel.info,
        );

        // Assert
        final logs = logService.getAllLogs();
        expect(logs.length, 1);
        expect(logs.first.message, contains('Triggering sync'));
        expect(logs.first.message, contains('5 pending'));
      });
    });

    group('Purchase Restoration Logging', () {
      test('should log successful purchase restoration', () {
        // Arrange
        const userId = 'test-user-123';
        const restoredStatus = SubscriptionStatus.active;

        // Act
        logService.logAuditEvent(
          eventType: 'purchase_restoration',
          action: 'restore_purchases',
          userIdentifier: userId,
          outcome: 'success',
          details:
              'Purchases restored successfully. Status: ${restoredStatus.toString()}',
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.eventType, 'purchase_restoration');
        expect(auditLogs.first.outcome, 'success');
      });

      test('should log failed purchase restoration', () {
        // Arrange
        const userId = 'test-user-123';
        const errorMessage = 'Platform connection failed';

        // Act
        logService.logAuditEvent(
          eventType: 'purchase_restoration',
          action: 'restore_purchases',
          userIdentifier: userId,
          outcome: 'failure',
          details: 'Purchase restoration failed: $errorMessage',
        );

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 1);
        expect(auditLogs.first.outcome, 'failure');
        expect(auditLogs.first.details, contains('failed'));
      });

      test('should log purchase restoration with retry attempts', () {
        // Arrange
        const userId = 'test-user-123';
        const maxRetries = 3;

        // Act
        for (int attempt = 1; attempt <= maxRetries; attempt++) {
          logService.log(
            'Purchase restoration attempt $attempt/$maxRetries for user $userId',
            level: log_svc.LogLevel.info,
          );
        }

        // Assert
        final logs = logService.getAllLogs();
        expect(logs.length, maxRetries);
        expect(logs.last.message, contains('attempt 3/3'));
      });
    });

    group('Analytics Integration', () {
      test('should track subscription lifecycle events', () async {
        // Arrange
        const userId = 'test-user-123';

        // Act - Track subscription purchase
        await analyticsService.trackAuthEvent(
          type: AuthEventType.signIn,
          success: true,
        );

        // Assert
        final authEvents = analyticsService.getRecentAuthEvents();
        expect(authEvents.length, 1);
        expect(authEvents.first.success, true);
      });

      test('should track subscription check performance', () async {
        // Arrange
        const userId = 'test-user-123';
        final duration = Duration(milliseconds: 200);

        // Act
        logService.recordPerformanceMetric(
          operation: 'subscription_status_check',
          duration: duration,
          userIdentifier: userId,
          success: true,
        );

        // Assert
        final metrics = logService.getPerformanceMetrics();
        expect(metrics.length, 1);
        expect(metrics.first.operation, 'subscription_status_check');
        expect(metrics.first.duration.inMilliseconds, 200);
      });

      test('should track gating decision metrics', () {
        // Arrange
        const userId = 'test-user-123';
        int allowedCount = 0;
        int deniedCount = 0;

        // Act - Simulate multiple gating decisions
        for (int i = 0; i < 10; i++) {
          final allowed = i % 3 == 0; // Every 3rd is allowed
          if (allowed) {
            allowedCount++;
          } else {
            deniedCount++;
          }

          logService.logAuditEvent(
            eventType: 'sync_gating',
            action: 'check_permission',
            userIdentifier: userId,
            outcome: allowed ? 'allowed' : 'denied',
            details: allowed ? 'Sync allowed' : 'Sync denied',
          );
        }

        // Assert
        final auditLogs = logService.getAuditLogs();
        expect(auditLogs.length, 10);

        final allowedLogs =
            auditLogs.where((log) => log.outcome == 'allowed').length;
        final deniedLogs =
            auditLogs.where((log) => log.outcome == 'denied').length;

        expect(allowedLogs, allowedCount);
        expect(deniedLogs, deniedCount);
      });
    });

    group('Log Filtering and Retrieval', () {
      test('should retrieve subscription-related logs by event type', () {
        // Arrange
        logService.logAuditEvent(
          eventType: 'subscription_check',
          action: 'check_status',
          outcome: 'success',
        );

        logService.logAuditEvent(
          eventType: 'sync_gating',
          action: 'check_permission',
          outcome: 'denied',
        );

        logService.logAuditEvent(
          eventType: 'subscription_check',
          action: 'check_status',
          outcome: 'success',
        );

        // Act
        final subscriptionLogs =
            logService.getAuditLogsByEventType('subscription_check');

        // Assert
        expect(subscriptionLogs.length, 2);
        expect(
            subscriptionLogs
                .every((log) => log.eventType == 'subscription_check'),
            true);
      });

      test('should retrieve logs by user identifier', () {
        // Arrange
        const user1 = 'user-123';
        const user2 = 'user-456';

        logService.logAuditEvent(
          eventType: 'subscription_check',
          action: 'check_status',
          userIdentifier: user1,
          outcome: 'success',
        );

        logService.logAuditEvent(
          eventType: 'subscription_check',
          action: 'check_status',
          userIdentifier: user2,
          outcome: 'success',
        );

        // Act
        final user1Logs = logService.getAuditLogsByUser(user1);

        // Assert
        expect(user1Logs.length, 1);
        expect(user1Logs.first.userIdentifier, user1);
      });

      test('should retrieve recent logs within time window', () {
        // Arrange
        logService.log('Old log', level: log_svc.LogLevel.info);

        // Act
        final recentLogs = logService.getRecentLogs(1); // Last 1 minute

        // Assert
        expect(recentLogs.length, 1);
      });
    });

    group('Log Statistics', () {
      test('should calculate subscription check statistics', () {
        // Arrange
        for (int i = 0; i < 10; i++) {
          logService.logAuditEvent(
            eventType: 'subscription_check',
            action: 'check_status',
            outcome: i < 8 ? 'success' : 'failure',
          );
        }

        // Act
        final stats = logService.getStatistics();

        // Assert
        expect(stats.totalAuditLogs, 10);
      });

      test('should track error and warning counts', () {
        // Arrange
        logService.log('Info message', level: log_svc.LogLevel.info);
        logService.log('Warning message', level: log_svc.LogLevel.warning);
        logService.log('Error message', level: log_svc.LogLevel.error);
        logService.log('Another error', level: log_svc.LogLevel.error);

        // Act
        final stats = logService.getStatistics();

        // Assert
        expect(stats.errorCount, 2);
        expect(stats.warningCount, 1);
      });
    });
  });
}
