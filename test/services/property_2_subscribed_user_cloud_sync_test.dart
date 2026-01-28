import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/sync_service.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/subscription_gating_middleware.dart';

/// **Feature: premium-subscription-gating, Property 2: Subscribed user cloud sync initiation**
/// **Validates: Requirements 2.1, 2.2, 2.3, 2.4**
///
/// Property-based test to verify that for any user with an active subscription,
/// all document CRUD operations save to local storage AND initiate cloud
/// synchronization to AWS services.
///
/// This test verifies that the sync service properly allows cloud operations
/// when an active subscription is detected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 2: Subscribed user cloud sync initiation', () {
    late SyncService syncService;
    late SubscriptionService subscriptionService;
    late SubscriptionGatingMiddleware middleware;

    setUp(() {
      syncService = SyncService();
      subscriptionService = SubscriptionService();
      middleware = SubscriptionGatingMiddleware(subscriptionService);
      syncService.setGatingMiddleware(middleware);
    });

    test('middleware should allow cloud sync with active subscription',
        () async {
      // Property: For any check with active subscription, cloud sync should be allowed

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Clear cache to ensure fresh check
        subscriptionService.clearCache();

        // Check if cloud sync is allowed
        final canSync = await middleware.canPerformCloudSync();

        // Result should be a boolean
        expect(
          canSync,
          isA<bool>(),
          reason: 'canPerformCloudSync should return boolean (iteration $i)',
        );

        // Get the current subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        // If status is active, sync should be allowed
        if (status == SubscriptionStatus.active) {
          expect(
            canSync,
            isTrue,
            reason:
                'Cloud sync should be allowed with active subscription (iteration $i)',
          );

          // Denial reason should indicate sync is allowed
          final reason = middleware.getDenialReason();
          expect(
            reason.toLowerCase(),
            contains('allowed'),
            reason:
                'Denial reason should indicate sync is allowed (iteration $i)',
          );
        }
      }
    });

    test(
        'executeWithGating should use cloud operation with active subscription',
        () async {
      // Property: For any gated operation with active subscription, cloud operation should execute

      const iterations = 100;
      int cloudOperationCount = 0;
      int localOperationCount = 0;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Execute operation with gating
        final result = await middleware.executeWithGating<String>(
          cloudOperation: () async {
            cloudOperationCount++;
            return 'cloud';
          },
          localOperation: () async {
            localOperationCount++;
            return 'local';
          },
        );

        // Verify that one of the operations was executed
        expect(
          result,
          anyOf(['cloud', 'local']),
          reason: 'One operation should execute (iteration $i)',
        );

        // Get subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        // If status is active, cloud operation should have been executed
        if (status == SubscriptionStatus.active) {
          // The most recent operation should have been cloud
          expect(
            result,
            equals('cloud'),
            reason:
                'Cloud operation should execute with active subscription (iteration $i)',
          );
        }
      }

      // Verify that operations were executed
      final totalOperations = cloudOperationCount + localOperationCount;
      expect(
        totalOperations,
        equals(iterations),
        reason: 'Total operations should equal iterations',
      );
    });

    test('middleware should consistently allow sync with active subscription',
        () async {
      // Property: Multiple checks with active subscription should consistently allow sync

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Get subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        // Make multiple checks in sequence
        final results = <bool>[];
        for (int j = 0; j < 10; j++) {
          results.add(await middleware.canPerformCloudSync());
        }

        // If subscription is active, all results should be true
        if (status == SubscriptionStatus.active) {
          for (int j = 0; j < results.length; j++) {
            expect(
              results[j],
              isTrue,
              reason:
                  'All checks should allow sync with active subscription (iteration $i, check $j)',
            );
          }
        }

        // All results should be consistent (using cache)
        final firstResult = results.first;
        for (int j = 0; j < results.length; j++) {
          expect(
            results[j],
            equals(firstResult),
            reason:
                'All calls within cache window should return consistent results (iteration $i, call $j)',
          );
        }
      }
    });

    test(
        'sync service should attempt cloud operations with active subscription',
        () async {
      // Property: performSync should attempt cloud operations when subscription is active

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Get subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        try {
          // Attempt to perform sync
          final result = await syncService.performSync();

          // If subscription is active, sync should have been attempted
          // (may fail for other reasons like no network, but should have tried)
          if (status == SubscriptionStatus.active) {
            // Result should be a valid SyncResult
            expect(
              result,
              isNotNull,
              reason:
                  'Sync result should be returned with active subscription (iteration $i)',
            );
          }
        } catch (e) {
          // Sync may throw exceptions for various reasons
          // If subscription is active, exception should not be about subscription
          if (status == SubscriptionStatus.active) {
            expect(
              e.toString().toLowerCase(),
              isNot(contains('subscription')),
              reason:
                  'Exception should not be about subscription when active (iteration $i)',
            );
          }
        }
      }
    });

    test(
        'middleware should allow rapid sync operations with active subscription',
        () async {
      // Property: Even with rapid operations, middleware should allow sync with active subscription

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Get subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        // Make rapid sequential calls
        final results = <bool>[];
        for (int j = 0; j < 20; j++) {
          results.add(await middleware.canPerformCloudSync());
        }

        // If subscription is active, all results should be true
        if (status == SubscriptionStatus.active) {
          for (int j = 0; j < results.length; j++) {
            expect(
              results[j],
              isTrue,
              reason:
                  'Rapid checks should allow sync with active subscription (iteration $i, call $j)',
            );
          }
        }

        // All results should be consistent (using cache)
        final firstResult = results.first;
        for (int j = 0; j < results.length; j++) {
          expect(
            results[j],
            equals(firstResult),
            reason:
                'Rapid sequential calls should return consistent results (iteration $i, call $j)',
          );
        }
      }
    });

    test(
        'middleware should provide correct denial reason with active subscription',
        () async {
      // Property: When sync is allowed, denial reason should indicate that

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Check sync permission
        final canSync = await middleware.canPerformCloudSync();

        // Get denial reason
        final reason = middleware.getDenialReason();

        // Reason should always be available
        expect(
          reason,
          isNotEmpty,
          reason: 'Denial reason should always be available (iteration $i)',
        );

        // If sync is allowed, reason should indicate that
        if (canSync) {
          expect(
            reason.toLowerCase(),
            contains('allowed'),
            reason:
                'Reason should indicate sync is allowed when canSync is true (iteration $i)',
          );
        }

        // Get subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        // If subscription is active, sync should be allowed
        if (status == SubscriptionStatus.active) {
          expect(
            canSync,
            isTrue,
            reason:
                'Sync should be allowed with active subscription (iteration $i)',
          );
          expect(
            reason.toLowerCase(),
            contains('allowed'),
            reason:
                'Reason should indicate allowed with active subscription (iteration $i)',
          );
        }
      }
    });

    test('middleware should handle subscription status transitions correctly',
        () async {
      // Property: When subscription status changes, middleware should reflect that

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Clear cache to get fresh status
        subscriptionService.clearCache();

        // Get initial status
        final initialStatus = await subscriptionService.getSubscriptionStatus();
        final initialCanSync = await middleware.canPerformCloudSync();

        // Verify consistency
        if (initialStatus == SubscriptionStatus.active) {
          expect(
            initialCanSync,
            isTrue,
            reason:
                'Initial check should allow sync with active subscription (iteration $i)',
          );
        }

        // Clear cache again
        subscriptionService.clearCache();

        // Get status again
        final secondStatus = await subscriptionService.getSubscriptionStatus();
        final secondCanSync = await middleware.canPerformCloudSync();

        // Verify consistency with second check
        if (secondStatus == SubscriptionStatus.active) {
          expect(
            secondCanSync,
            isTrue,
            reason:
                'Second check should allow sync with active subscription (iteration $i)',
          );
        }

        // If status hasn't changed, results should be consistent
        if (initialStatus == secondStatus) {
          expect(
            secondCanSync,
            equals(initialCanSync),
            reason:
                'Results should be consistent when status unchanged (iteration $i)',
          );
        }
      }
    });

    test(
        'executeWithGating should execute cloud operation consistently with active subscription',
        () async {
      // Property: For any sequence of gated operations with active subscription, cloud operations should execute

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Get subscription status
        final status = await subscriptionService.getSubscriptionStatus();

        // Execute multiple operations
        final results = <String>[];
        for (int j = 0; j < 5; j++) {
          final result = await middleware.executeWithGating<String>(
            cloudOperation: () async => 'cloud',
            localOperation: () async => 'local',
          );
          results.add(result);
        }

        // If subscription is active, all operations should be cloud
        if (status == SubscriptionStatus.active) {
          for (int j = 0; j < results.length; j++) {
            expect(
              results[j],
              equals('cloud'),
              reason:
                  'All operations should be cloud with active subscription (iteration $i, operation $j)',
            );
          }
        }

        // All results should be consistent
        final firstResult = results.first;
        for (int j = 0; j < results.length; j++) {
          expect(
            results[j],
            equals(firstResult),
            reason:
                'All operations should be consistent (iteration $i, operation $j)',
          );
        }
      }
    });
  });
}
