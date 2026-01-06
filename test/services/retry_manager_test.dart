import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/retry_manager.dart';
import 'dart:async';
import 'dart:math';

void main() {
  group('RetryManager', () {
    late RetryManager retryManager;

    setUp(() {
      retryManager = RetryManager();
    });

    group('Property Tests', () {
      test(
          'Property 12: Network Error Retry - **Feature: cloud-sync-implementation-fix, Property 12: Network Error Retry**',
          () async {
        // **Validates: Requirements 4.1**

        // Property: For any operation that fails due to network errors,
        // it should be retried with exponential backoff up to 5 times

        final random = Random();

        // Test multiple scenarios with different network errors
        for (int scenario = 0; scenario < 10; scenario++) {
          // Generate random network error types
          final networkErrors = [
            'Network unreachable',
            'Connection timeout',
            'No internet connection',
            'Socket exception',
            'DNS resolution failed',
            'Connection refused',
          ];

          final errorMessage =
              networkErrors[random.nextInt(networkErrors.length)];
          int attemptCount = 0;
          const maxRetries = 5;

          // Track retry attempts and delays
          final retryAttempts = <int>[];
          final retryDelays = <Duration>[];
          DateTime? lastAttemptTime;

          try {
            await retryManager.executeWithRetry(
              () async {
                attemptCount++;
                retryAttempts.add(attemptCount);

                // Track delay between attempts
                if (lastAttemptTime != null) {
                  final delay = DateTime.now().difference(lastAttemptTime!);
                  retryDelays.add(delay);
                }
                lastAttemptTime = DateTime.now();

                // Always fail with network error for this test
                throw Exception(errorMessage);
              },
              config: const RetryConfig(
                maxRetries: 5,
                baseDelay: Duration(milliseconds: 100), // Faster for testing
                backoffMultiplier: 2.0,
                maxDelay: Duration(seconds: 1),
                useJitter: false, // Disable jitter for predictable testing
              ),
            );

            // Should never reach here
            fail('Expected operation to fail after retries');
          } catch (e) {
            // Verify the operation was retried the correct number of times
            expect(attemptCount, equals(maxRetries + 1),
                reason:
                    'Should attempt operation ${maxRetries + 1} times (initial + $maxRetries retries)');

            // Verify exponential backoff delays
            expect(retryDelays.length, equals(maxRetries),
                reason: 'Should have $maxRetries delays between attempts');

            // Verify delays follow exponential backoff pattern (capped at maxDelay)
            for (int i = 0; i < retryDelays.length; i++) {
              final expectedDelayMs =
                  (100 * pow(2.0, i)).toInt(); // 100ms * 2^i
              final cappedDelayMs = expectedDelayMs > 1000
                  ? 1000
                  : expectedDelayMs; // Cap at 1000ms
              final actualDelayMs = retryDelays[i].inMilliseconds;

              // Allow some tolerance for timing variations (±50ms)
              expect(actualDelayMs, greaterThanOrEqualTo(cappedDelayMs - 50),
                  reason:
                      'Delay $i should be at least ${cappedDelayMs - 50}ms, got ${actualDelayMs}ms');
              expect(actualDelayMs, lessThanOrEqualTo(cappedDelayMs + 100),
                  reason:
                      'Delay $i should be at most ${cappedDelayMs + 100}ms, got ${actualDelayMs}ms');
            }

            // Verify final exception is the network error
            expect(e.toString(), contains(errorMessage),
                reason:
                    'Final exception should contain the original error message');
          }
        }
      });

      test('Network errors are properly identified as retryable', () {
        final retryManager = RetryManager();

        // Test various network error patterns
        final networkErrors = [
          Exception('Network unreachable'),
          Exception('Connection timeout'),
          Exception('No internet connection'),
          Exception('Socket exception occurred'),
          Exception('DNS resolution failed'),
          Exception('Connection refused'),
          TimeoutException('Operation timed out'),
        ];

        for (final error in networkErrors) {
          final isNetwork = retryManager.isNetworkError(error);
          final isTimeout = retryManager.isTimeoutError(error);
          expect(isNetwork || isTimeout, isTrue,
              reason:
                  'Error should be identified as network or timeout error: $error');
        }
      });

      test('Non-network errors are not retried by default', () async {
        final retryManager = RetryManager();
        int attemptCount = 0;

        // Test with validation error (should not retry)
        try {
          await retryManager.executeWithRetry(() async {
            attemptCount++;
            throw ArgumentError('Invalid input data');
          });
          fail('Expected operation to fail');
        } catch (e) {
          // Should only attempt once (no retries for validation errors)
          expect(attemptCount, equals(1),
              reason: 'Validation errors should not be retried');
          expect(e, isA<ArgumentError>());
        }
      });

      test('Custom retry logic is respected', () async {
        final retryManager = RetryManager();
        int attemptCount = 0;

        // Test with custom retry logic that retries ArgumentError
        try {
          await retryManager.executeWithRetry(
            () async {
              attemptCount++;
              throw ArgumentError('Custom retryable error');
            },
            config: const RetryConfig(
              maxRetries: 2,
              baseDelay: Duration(milliseconds: 10),
            ),
            shouldRetry: (error) => error is ArgumentError,
          );
          fail('Expected operation to fail');
        } catch (e) {
          // Should attempt 3 times (initial + 2 retries)
          expect(attemptCount, equals(3),
              reason: 'Custom retry logic should allow ArgumentError retries');
        }
      });

      test('Successful operation after retries returns result', () async {
        final retryManager = RetryManager();
        int attemptCount = 0;
        const expectedResult = 'success';

        final result = await retryManager.executeWithRetry(() async {
          attemptCount++;
          if (attemptCount < 3) {
            throw Exception('Network error');
          }
          return expectedResult;
        });

        expect(result, equals(expectedResult),
            reason: 'Should return result when operation succeeds');
        expect(attemptCount, equals(3),
            reason: 'Should have attempted 3 times before success');
      });

      test('Jitter adds randomness to delays', () async {
        final retryManager = RetryManager();
        final delays = <Duration>[];

        // Run multiple tests to collect delay samples
        for (int test = 0; test < 5; test++) {
          DateTime? lastAttemptTime;
          int attemptCount = 0;

          try {
            await retryManager.executeWithRetry(
              () async {
                attemptCount++;

                if (lastAttemptTime != null) {
                  final delay = DateTime.now().difference(lastAttemptTime!);
                  delays.add(delay);
                }
                lastAttemptTime = DateTime.now();

                if (attemptCount <= 2) {
                  throw Exception('Network error');
                }
                // Succeed on third attempt to collect delay data
              },
              config: const RetryConfig(
                maxRetries: 3,
                baseDelay: Duration(milliseconds: 100),
                backoffMultiplier: 2.0,
                useJitter: true,
              ),
            );
          } catch (e) {
            // Ignore failures, we're just collecting delay data
          }
        }

        // Verify we have some delay samples
        expect(delays.isNotEmpty, isTrue,
            reason: 'Should have collected delay samples');

        // Verify delays are not all identical (jitter adds variation)
        if (delays.length > 1) {
          final firstDelay = delays.first.inMilliseconds;
          final hasVariation =
              delays.any((d) => d.inMilliseconds != firstDelay);
          expect(hasVariation, isTrue,
              reason: 'Jitter should add variation to delays');
        }
      });
    });
  });
}
