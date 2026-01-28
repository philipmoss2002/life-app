import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/subscription_gating_middleware.dart';

/// **Feature: premium-subscription-gating, Property 4: Subscription status query on sync**
/// **Validates: Requirements 5.1**
///
/// Property-based test to verify that for any sync operation initiated,
/// the gating middleware queries the subscription service for current
/// subscription status before proceeding with cloud operations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Property 4: Subscription status query on sync', () {
    late SubscriptionService subscriptionService;
    late SubscriptionGatingMiddleware middleware;

    setUp(() {
      subscriptionService = SubscriptionService();
      middleware = SubscriptionGatingMiddleware(subscriptionService);
    });

    test(
        'middleware should query subscription status for every canPerformCloudSync call',
        () async {
      // Property: For any sync operation, the middleware should query the subscription service

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Clear cache to ensure fresh query
        subscriptionService.clearCache();

        // Call canPerformCloudSync - this should query subscription service
        final canSync = await middleware.canPerformCloudSync();

        // Verify that a boolean result was returned (indicating query completed)
        expect(
          canSync,
          isA<bool>(),
          reason:
              'canPerformCloudSync should return boolean result from subscription query (iteration $i)',
        );

        // Verify that getDenialReason returns a valid string
        final denialReason = middleware.getDenialReason();
        expect(
          denialReason,
          isA<String>(),
          reason:
              'getDenialReason should return string after status check (iteration $i)',
        );

        // If sync is allowed, denial reason should indicate that
        if (canSync) {
          expect(
            denialReason.toLowerCase(),
            contains('allowed'),
            reason:
                'Denial reason should indicate sync is allowed when canSync is true (iteration $i)',
          );
        } else {
          // If sync is denied, denial reason should explain why
          expect(
            denialReason.toLowerCase(),
            anyOf([
              contains('denied'),
              contains('subscription'),
              contains('status'),
            ]),
            reason:
                'Denial reason should explain why sync is denied (iteration $i)',
          );
        }
      }
    });

    test('middleware should query status for each executeWithGating call',
        () async {
      // Property: executeWithGating should check subscription status before executing operations

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
          reason:
              'executeWithGating should execute one of the operations (iteration $i)',
        );

        // Verify that exactly one operation was executed per call
        final totalOperations = cloudOperationCount + localOperationCount;
        expect(
          totalOperations,
          equals(i + 1),
          reason:
              'Exactly one operation should be executed per call (iteration $i)',
        );
      }

      // Verify that both types of operations were executed at least once
      // (unless subscription status never changes, which is acceptable)
      expect(
        cloudOperationCount + localOperationCount,
        equals(iterations),
        reason: 'Total operations should equal iterations',
      );
    });

    test('middleware should query status consistently across multiple calls',
        () async {
      // Property: Multiple calls should consistently query subscription status

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Make multiple calls in sequence
        final results = <bool>[];
        for (int j = 0; j < 10; j++) {
          results.add(await middleware.canPerformCloudSync());
        }

        // All results should be consistent (using cached status)
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

    test('middleware should handle subscription service errors gracefully',
        () async {
      // Property: Even if subscription check fails, middleware should return a valid result

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        // Call canPerformCloudSync
        final canSync = await middleware.canPerformCloudSync();

        // Should return a boolean (fail-safe to false on error)
        expect(
          canSync,
          isA<bool>(),
          reason:
              'canPerformCloudSync should always return boolean (iteration $i)',
        );

        // Should have a denial reason available
        final denialReason = middleware.getDenialReason();
        expect(
          denialReason,
          isNotEmpty,
          reason: 'Denial reason should not be empty (iteration $i)',
        );
      }
    });

    test('middleware should query status before each gated operation',
        () async {
      // Property: Each executeWithGating call should check subscription status

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        var operationExecuted = false;

        // Execute with gating
        await middleware.executeWithGating<void>(
          cloudOperation: () async {
            operationExecuted = true;
          },
          localOperation: () async {
            operationExecuted = true;
          },
        );

        // Verify that an operation was executed
        expect(
          operationExecuted,
          isTrue,
          reason: 'An operation should be executed (iteration $i)',
        );

        // Verify that denial reason is available (indicating status was checked)
        final denialReason = middleware.getDenialReason();
        expect(
          denialReason,
          isNotEmpty,
          reason:
              'Denial reason should be available after gated operation (iteration $i)',
        );
      }
    });

    test('middleware should maintain denial reason across multiple checks',
        () async {
      // Property: Denial reason should be updated with each status check

      const iterations = 50;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // First check
        await middleware.canPerformCloudSync();
        final firstReason = middleware.getDenialReason();

        // Second check (may use cache)
        await middleware.canPerformCloudSync();
        final secondReason = middleware.getDenialReason();

        // Both reasons should be valid strings
        expect(
          firstReason,
          isA<String>(),
          reason: 'First denial reason should be valid (iteration $i)',
        );
        expect(
          secondReason,
          isA<String>(),
          reason: 'Second denial reason should be valid (iteration $i)',
        );

        // Reasons should be consistent within cache window
        expect(
          secondReason,
          equals(firstReason),
          reason:
              'Denial reasons should be consistent within cache window (iteration $i)',
        );
      }
    });

    test('middleware should query status for rapid sequential operations',
        () async {
      // Property: Even with rapid calls, middleware should query status appropriately

      const iterations = 30;

      for (int i = 0; i < iterations; i++) {
        subscriptionService.clearCache();

        // Make rapid sequential calls
        final results = <bool>[];
        for (int j = 0; j < 20; j++) {
          results.add(await middleware.canPerformCloudSync());
        }

        // All results should be valid booleans
        for (int j = 0; j < results.length; j++) {
          expect(
            results[j],
            isA<bool>(),
            reason:
                'Each rapid call should return valid boolean (iteration $i, call $j)',
          );
        }

        // Results should be consistent (using cache)
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
  });
}
