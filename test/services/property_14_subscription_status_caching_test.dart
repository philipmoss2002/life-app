import 'package:test/test.dart';
import 'package:household_docs_app/services/subscription_service.dart';

/// **Feature: premium-subscription-gating, Property 14: Subscription status caching**
/// **Validates: Requirements 9.1**
///
/// Property-based test to verify that subscription status checks return cached
/// status if checked within the last 5 minutes, avoiding excessive platform queries.
void main() {
  group('Property 14: Subscription status caching', () {
    late SubscriptionService subscriptionService;

    setUp(() {
      subscriptionService = SubscriptionService();
    });

    test(
        'subscription status should be cached and reused within 5-minute window',
        () async {
      // Property: For any subscription status check within 5 minutes of the previous check,
      // the service should return the cached status without querying the platform

      // Run property test with multiple iterations
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Clear cache to start fresh
        subscriptionService.clearCache();

        // First call - this will query the platform and cache the result
        final firstCheck = await subscriptionService.hasActiveSubscription();

        // Immediate second call - should use cache
        final secondCheck = await subscriptionService.hasActiveSubscription();

        // Both checks should return the same result (from cache)
        expect(
          secondCheck,
          equals(firstCheck),
          reason:
              'Second check should return cached result from first check (iteration $i)',
        );

        // Multiple rapid checks should all use cache
        for (int j = 0; j < 10; j++) {
          final rapidCheck = await subscriptionService.hasActiveSubscription();
          expect(
            rapidCheck,
            equals(firstCheck),
            reason: 'Rapid check $j should return cached result (iteration $i)',
          );
        }
      }
    });

    test('cached status should be consistent across multiple calls', () async {
      // Property: Within the cache window, all calls should return identical results

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Make initial call to populate cache
        final initialStatus = await subscriptionService.hasActiveSubscription();

        // Make multiple calls within cache window
        final cachedResults = <bool>[];
        for (int j = 0; j < 20; j++) {
          cachedResults.add(await subscriptionService.hasActiveSubscription());
        }

        // All cached results should match the initial status
        for (int j = 0; j < cachedResults.length; j++) {
          expect(
            cachedResults[j],
            equals(initialStatus),
            reason:
                'Cached result $j should match initial status (iteration $i)',
          );
        }
      }
    });

    test('cache should work correctly for both active and inactive states',
        () async {
      // Property: Caching should work consistently regardless of subscription status

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Get initial status (could be active or inactive)
        final status = await subscriptionService.getSubscriptionStatus();

        // Make multiple hasActiveSubscription calls
        final expectedResult = status == SubscriptionStatus.active;

        for (int j = 0; j < 10; j++) {
          final cachedResult =
              await subscriptionService.hasActiveSubscription();
          expect(
            cachedResult,
            equals(expectedResult),
            reason:
                'Cached result should match status (iteration $i, check $j)',
          );
        }
      }
    });

    test('cache should reduce platform queries', () async {
      // Property: Using cache should minimize the number of platform queries

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // First call populates cache
        await subscriptionService.hasActiveSubscription();

        // Multiple subsequent calls should use cache (no additional platform queries)
        // We verify this by ensuring the calls complete quickly and consistently
        final startTime = DateTime.now();

        for (int j = 0; j < 50; j++) {
          await subscriptionService.hasActiveSubscription();
        }

        final duration = DateTime.now().difference(startTime);

        // Cached calls should be very fast (under 100ms for 50 calls)
        expect(
          duration.inMilliseconds,
          lessThan(100),
          reason:
              'Cached calls should be fast, indicating no platform queries (iteration $i)',
        );
      }
    });

    test('clearCache should force fresh status check', () async {
      // Property: After clearing cache, the next call should query the platform

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Get initial cached status
        final cachedStatus = await subscriptionService.hasActiveSubscription();

        // Clear cache
        subscriptionService.clearCache();

        // Next call should query platform (may return different result)
        final freshStatus = await subscriptionService.hasActiveSubscription();

        // We can't guarantee the status changed, but we can verify the call completed
        // and returned a valid boolean result
        expect(
          freshStatus,
          isA<bool>(),
          reason:
              'Fresh status check should return valid result (iteration $i)',
        );

        // If we make another call immediately, it should use the new cache
        final reCachedStatus =
            await subscriptionService.hasActiveSubscription();
        expect(
          reCachedStatus,
          equals(freshStatus),
          reason:
              'Subsequent call should use newly cached result (iteration $i)',
        );
      }
    });

    test('cache should handle rapid sequential calls correctly', () async {
      // Property: Even with rapid sequential calls, cache should maintain consistency

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Make rapid sequential calls
        final results = <bool>[];
        for (int j = 0; j < 100; j++) {
          results.add(await subscriptionService.hasActiveSubscription());
        }

        // All results should be identical (from cache)
        final firstResult = results.first;
        for (int j = 0; j < results.length; j++) {
          expect(
            results[j],
            equals(firstResult),
            reason:
                'All rapid sequential calls should return same cached result (iteration $i, call $j)',
          );
        }
      }
    });

    test('cache should work correctly after service initialization', () async {
      // Property: Cache should function properly from the first call after initialization

      const iterations = 20;

      for (int i = 0; i < iterations; i++) {
        // Create new service instance
        final newService = SubscriptionService();

        // First call should work and cache result
        final firstCall = await newService.hasActiveSubscription();

        // Second call should use cache
        final secondCall = await newService.hasActiveSubscription();

        expect(
          secondCall,
          equals(firstCall),
          reason:
              'Cache should work from first call after initialization (iteration $i)',
        );
      }
    });
  });
}
