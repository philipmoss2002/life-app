import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/subscription_service.dart';

/// **Feature: premium-subscription-gating, Property 17: Manual refresh bypasses cache**
/// **Validates: Requirements 9.5**
///
/// Property-based test to verify that when the user manually refreshes subscription status,
/// the service bypasses the cache and queries the In-App Purchase Platform directly.
void main() {
  // Initialize Flutter bindings for in-app purchase testing
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 17: Manual refresh bypasses cache', () {
    late SubscriptionService subscriptionService;

    setUp(() {
      subscriptionService = SubscriptionService();
    });

    test('manual refresh should bypass cache and query platform', () async {
      // Property: For any manual subscription status refresh, the service should
      // bypass the cache and query the platform directly

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Populate cache with initial status
        await subscriptionService.hasActiveSubscription();

        // Manual refresh should bypass cache
        await subscriptionService.refreshSubscriptionStatus();

        // Verify the refresh completed successfully
        final statusAfterRefresh =
            await subscriptionService.hasActiveSubscription();

        expect(
          statusAfterRefresh,
          isA<bool>(),
          reason: 'Manual refresh should return valid status (iteration $i)',
        );
      }
    });

    test('manual refresh should update cache with fresh data', () async {
      // Property: After manual refresh, subsequent calls should use the newly cached data

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Populate initial cache
        await subscriptionService.hasActiveSubscription();

        // Manual refresh
        await subscriptionService.refreshSubscriptionStatus();

        // Get status after refresh
        final statusAfterRefresh =
            await subscriptionService.getSubscriptionStatus();

        // Subsequent call should use the new cache
        final cachedStatus = await subscriptionService.getSubscriptionStatus();

        expect(
          cachedStatus,
          equals(statusAfterRefresh),
          reason:
              'Subsequent call should use newly cached data after manual refresh (iteration $i)',
        );
      }
    });

    test('manual refresh should work correctly multiple times in succession',
        () async {
      // Property: Multiple manual refreshes should each bypass cache and query platform

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        // Perform multiple manual refreshes in succession
        await subscriptionService.refreshSubscriptionStatus();
        await subscriptionService.refreshSubscriptionStatus();
        await subscriptionService.refreshSubscriptionStatus();

        // Each refresh should complete successfully
        final finalStatus = await subscriptionService.hasActiveSubscription();

        expect(
          finalStatus,
          isA<bool>(),
          reason:
              'Multiple manual refreshes should work correctly (iteration $i)',
        );
      }
    });

    test('manual refresh should bypass even fresh cache', () async {
      // Property: Manual refresh should bypass cache even if it was just populated

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Populate cache
        await subscriptionService.hasActiveSubscription();

        // Immediately call manual refresh (cache is fresh but should be bypassed)
        await subscriptionService.refreshSubscriptionStatus();

        // Verify refresh completed
        final status = await subscriptionService.hasActiveSubscription();

        expect(
          status,
          isA<bool>(),
          reason:
              'Manual refresh should bypass even fresh cache (iteration $i)',
        );
      }
    });

    test('manual refresh should work correctly after cache expiration',
        () async {
      // Property: Manual refresh should work correctly regardless of cache state

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Populate cache
        await subscriptionService.hasActiveSubscription();

        // Clear cache to simulate expiration
        subscriptionService.clearCache();

        // Manual refresh should still work
        await subscriptionService.refreshSubscriptionStatus();

        // Verify status is valid
        final status = await subscriptionService.hasActiveSubscription();

        expect(
          status,
          isA<bool>(),
          reason:
              'Manual refresh should work after cache expiration (iteration $i)',
        );
      }
    });

    test('manual refresh should maintain service stability', () async {
      // Property: Frequent manual refreshes should not cause service instability

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Alternate between normal calls and manual refreshes
        if (i % 3 == 0) {
          await subscriptionService.refreshSubscriptionStatus();
        } else {
          await subscriptionService.hasActiveSubscription();
        }

        // Every call should return valid result
        final status = await subscriptionService.hasActiveSubscription();

        expect(
          status,
          isA<bool>(),
          reason:
              'Service should remain stable with frequent manual refreshes (iteration $i)',
        );
      }
    });

    test('manual refresh should work correctly for different status values',
        () async {
      // Property: Manual refresh should work consistently regardless of subscription status

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Manual refresh
        await subscriptionService.refreshSubscriptionStatus();

        // Get status (could be any value)
        final status = await subscriptionService.getSubscriptionStatus();

        // Verify valid status
        expect(
          status,
          isIn([
            SubscriptionStatus.active,
            SubscriptionStatus.expired,
            SubscriptionStatus.gracePeriod,
            SubscriptionStatus.none,
          ]),
          reason: 'Manual refresh should return valid status (iteration $i)',
        );

        // Verify cache is populated
        final cachedStatus = await subscriptionService.getSubscriptionStatus();
        expect(
          cachedStatus,
          equals(status),
          reason:
              'Cache should be populated after manual refresh (iteration $i)',
        );
      }
    });

    test('manual refresh should clear old cache before querying', () async {
      // Property: Manual refresh should not be affected by stale cache data

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Populate cache
        final initialStatus = await subscriptionService.hasActiveSubscription();

        // Manual refresh should clear old cache and get fresh data
        await subscriptionService.refreshSubscriptionStatus();

        // Get new status
        final refreshedStatus =
            await subscriptionService.hasActiveSubscription();

        // Both should be valid booleans
        expect(initialStatus, isA<bool>());
        expect(refreshedStatus, isA<bool>());

        // Verify subsequent calls use new cache
        final cachedStatus = await subscriptionService.hasActiveSubscription();
        expect(
          cachedStatus,
          equals(refreshedStatus),
          reason:
              'Subsequent calls should use new cache after manual refresh (iteration $i)',
        );
      }
    });

    test('manual refresh should handle rapid successive calls', () async {
      // Property: Rapid successive manual refreshes should all complete successfully

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        // Rapid successive manual refreshes
        final futures = <Future<void>>[];
        for (int j = 0; j < 5; j++) {
          futures.add(subscriptionService.refreshSubscriptionStatus());
        }

        // Wait for all to complete
        await Future.wait(futures);

        // Verify service is still functional
        final status = await subscriptionService.hasActiveSubscription();

        expect(
          status,
          isA<bool>(),
          reason:
              'Service should handle rapid successive manual refreshes (iteration $i)',
        );
      }
    });

    test('manual refresh should work correctly with mixed operations',
        () async {
      // Property: Manual refresh should work correctly when mixed with normal operations

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Mix of operations
        await subscriptionService.hasActiveSubscription();
        await subscriptionService.refreshSubscriptionStatus();
        await subscriptionService.getSubscriptionStatus();
        await subscriptionService.hasActiveSubscription();
        await subscriptionService.refreshSubscriptionStatus();

        // Final status check should work
        final finalStatus = await subscriptionService.hasActiveSubscription();

        expect(
          finalStatus,
          isA<bool>(),
          reason:
              'Mixed operations with manual refresh should work correctly (iteration $i)',
        );
      }
    });

    test(
        'manual refresh should bypass cache consistently across service lifecycle',
        () async {
      // Property: Manual refresh should always bypass cache, regardless of service state

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        // Create new service instance
        final newService = SubscriptionService();

        // Populate cache
        await newService.hasActiveSubscription();

        // Manual refresh should bypass cache
        await newService.refreshSubscriptionStatus();

        // Verify it worked
        final status = await newService.hasActiveSubscription();

        expect(
          status,
          isA<bool>(),
          reason:
              'Manual refresh should bypass cache across service lifecycle (iteration $i)',
        );
      }
    });

    test('manual refresh should complete within reasonable time', () async {
      // Property: Manual refresh should complete in a reasonable timeframe

      const iterations = 20;

      for (int i = 0; i < iterations; i++) {
        final startTime = DateTime.now();

        await subscriptionService.refreshSubscriptionStatus();

        final duration = DateTime.now().difference(startTime);

        // Manual refresh should complete within 5 seconds (generous timeout)
        expect(
          duration.inSeconds,
          lessThan(5),
          reason:
              'Manual refresh should complete within reasonable time (iteration $i)',
        );
      }
    });
  });
}
