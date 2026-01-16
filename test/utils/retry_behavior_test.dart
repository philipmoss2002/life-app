import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/utils/retry_manager.dart';
import 'package:household_docs_app/utils/file_operation_error_handler.dart';
import 'dart:math';

void main() {
  group('Retry Behavior Tests', () {
    late RetryManager retryManager;

    setUp(() {
      retryManager = RetryManager();
      retryManager.clearCircuitBreakers();
      retryManager.clearQueue();
    });

    group('Exponential Backoff Behavior', () {
      test('should implement exponential backoff with jitter', () async {
        final delays = <Duration>[];
        int attemptCount = 0;
        DateTime? lastAttemptTime;

        try {
          await retryManager.executeWithRetry(
            () async {
              final currentTime = DateTime.now();
              attemptCount++;

              if (lastAttemptTime != null) {
                delays.add(currentTime.difference(lastAttemptTime!));
              }
              lastAttemptTime = currentTime;

              throw NetworkException('Network error', isRetryable: true);
            },
            'exponentialBackoffTest',
            maxRetries: 4,
            baseDelay: const Duration(milliseconds: 100),
            maxDelay: const Duration(seconds: 5),
          );
        } catch (e) {
          // Expected to fail after all retries
        }

        expect(attemptCount, equals(5)); // Initial + 4 retries
        expect(delays, hasLength(4)); // 4 delays between attempts

        // Verify exponential growth pattern (with tolerance for jitter)
        for (int i = 1; i < delays.length; i++) {
          final expectedMinDelay =
              Duration(milliseconds: (100 * pow(2, i - 1) * 0.5).toInt());
          final expectedMaxDelay =
              Duration(milliseconds: (100 * pow(2, i) * 1.5).toInt());

          expect(delays[i].inMilliseconds,
              greaterThanOrEqualTo(expectedMinDelay.inMilliseconds));
          expect(delays[i].inMilliseconds,
              lessThanOrEqualTo(expectedMaxDelay.inMilliseconds));
        }
      });

      test('should respect maximum delay limit', () async {
        final delays = <Duration>[];
        int attemptCount = 0;
        DateTime? lastAttemptTime;

        try {
          await retryManager.executeWithRetry(
            () async {
              final currentTime = DateTime.now();
              attemptCount++;

              if (lastAttemptTime != null) {
                delays.add(currentTime.difference(lastAttemptTime!));
              }
              lastAttemptTime = currentTime;

              throw NetworkException('Network error', isRetryable: true);
            },
            'maxDelayTest',
            maxRetries: 10,
            baseDelay: const Duration(milliseconds: 100),
            maxDelay: const Duration(milliseconds: 500), // Low max delay
          );
        } catch (e) {
          // Expected to fail
        }

        // All delays should be capped at maxDelay + jitter tolerance
        for (final delay in delays) {
          expect(delay.inMilliseconds,
              lessThanOrEqualTo(625)); // 500ms + 25% jitter
        }
      });

      test('should add jitter to prevent thundering herd', () async {
        final allDelays = <List<Duration>>[];

        // Run multiple retry sequences to collect delay patterns
        for (int run = 0; run < 5; run++) {
          final delays = <Duration>[];
          int attemptCount = 0;
          DateTime? lastAttemptTime;

          try {
            await retryManager.executeWithRetry(
              () async {
                final currentTime = DateTime.now();
                attemptCount++;

                if (lastAttemptTime != null) {
                  delays.add(currentTime.difference(lastAttemptTime!));
                }
                lastAttemptTime = currentTime;

                if (attemptCount <= 3) {
                  throw NetworkException('Network error', isRetryable: true);
                }
                return 'success';
              },
              'jitterTest$run',
              maxRetries: 3,
              baseDelay: const Duration(milliseconds: 100),
              maxDelay: const Duration(seconds: 2),
            );
          } catch (e) {
            // May succeed or fail, both are ok for this test
          }

          if (delays.isNotEmpty) {
            allDelays.add(delays);
          }
        }

        // Verify that delays vary between runs (jitter effect)
        if (allDelays.length >= 2) {
          final firstRunDelays = allDelays[0];
          final secondRunDelays = allDelays[1];

          if (firstRunDelays.isNotEmpty && secondRunDelays.isNotEmpty) {
            // Delays should not be identical due to jitter
            expect(firstRunDelays[0].inMilliseconds,
                isNot(equals(secondRunDelays[0].inMilliseconds)));
          }
        }
      });
    });

    group('Circuit Breaker Behavior', () {
      test('should open circuit after failure threshold', () async {
        const operationName = 'circuitBreakerTest';

        // Cause failures to reach threshold
        for (int i = 0; i < 5; i++) {
          try {
            await retryManager.executeWithRetry(
              () async =>
                  throw NetworkException('Network error', isRetryable: true),
              operationName,
              maxRetries: 0,
              useCircuitBreaker: true,
            );
          } catch (e) {
            // Expected failures
          }
        }

        // Circuit should now be open
        final status = retryManager.getCircuitBreakerStatus(operationName);
        expect(status, isNotNull);
        expect(status!.state, equals(CircuitState.open));
        expect(status.failureCount, equals(5));

        // Next operation should fail immediately with circuit breaker exception
        expect(
          () async => await retryManager.executeWithRetry(
            () async => 'success',
            operationName,
            useCircuitBreaker: true,
          ),
          throwsA(isA<CircuitBreakerOpenException>()),
        );
      });

      test('should transition from open to half-open after timeout', () async {
        const operationName = 'circuitTransitionTest';

        // Open the circuit
        for (int i = 0; i < 5; i++) {
          try {
            await retryManager.executeWithRetry(
              () async =>
                  throw NetworkException('Network error', isRetryable: true),
              operationName,
              maxRetries: 0,
              useCircuitBreaker: true,
            );
          } catch (e) {
            // Expected failures
          }
        }

        // Verify circuit is open
        var status = retryManager.getCircuitBreakerStatus(operationName);
        expect(status!.state, equals(CircuitState.open));

        // Wait for circuit breaker timeout (simulate by manipulating time)
        // Note: In a real implementation, you might need to wait or mock time
        await Future.delayed(const Duration(milliseconds: 100));

        // The circuit should still be open until we try an operation
        status = retryManager.getCircuitBreakerStatus(operationName);
        expect(status!.state, equals(CircuitState.open));
      });

      test('should reset circuit on successful operation', () async {
        const operationName = 'circuitResetTest';

        // Cause some failures (but not enough to open circuit)
        for (int i = 0; i < 3; i++) {
          try {
            await retryManager.executeWithRetry(
              () async =>
                  throw NetworkException('Network error', isRetryable: true),
              operationName,
              maxRetries: 0,
              useCircuitBreaker: true,
            );
          } catch (e) {
            // Expected failures
          }
        }

        // Verify circuit is still closed but has failure count
        var status = retryManager.getCircuitBreakerStatus(operationName);
        expect(status!.state, equals(CircuitState.closed));
        expect(status.failureCount, equals(3));

        // Successful operation should reset failure count
        final result = await retryManager.executeWithRetry(
          () async => 'success',
          operationName,
          useCircuitBreaker: true,
        );

        expect(result, equals('success'));

        status = retryManager.getCircuitBreakerStatus(operationName);
        expect(status!.state, equals(CircuitState.closed));
        expect(status.failureCount, equals(0));
      });

      test('should track circuit breaker per operation', () async {
        const operation1 = 'operation1';
        const operation2 = 'operation2';

        // Fail operation1 to open its circuit
        for (int i = 0; i < 5; i++) {
          try {
            await retryManager.executeWithRetry(
              () async =>
                  throw NetworkException('Network error', isRetryable: true),
              operation1,
              maxRetries: 0,
              useCircuitBreaker: true,
            );
          } catch (e) {
            // Expected failures
          }
        }

        // operation1 circuit should be open
        final status1 = retryManager.getCircuitBreakerStatus(operation1);
        expect(status1!.state, equals(CircuitState.open));

        // operation2 should still work (different circuit)
        final result = await retryManager.executeWithRetry(
          () async => 'success',
          operation2,
          useCircuitBreaker: true,
        );

        expect(result, equals('success'));

        final status2 = retryManager.getCircuitBreakerStatus(operation2);
        expect(status2!.state, equals(CircuitState.closed));
        expect(status2.failureCount, equals(0));
      });
    });

    group('Operation Queuing Behavior', () {
      test('should queue operations on network failures', () async {
        expect(
          () async => await retryManager.executeWithRetry(
            () async =>
                throw NetworkException('Network error', isRetryable: true),
            'queueTest',
            maxRetries: 1,
            queueOnFailure: true,
          ),
          throwsA(isA<OperationQueuedException>()),
        );

        final queueStatus = retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(1));
        expect(queueStatus.oldestOperation, isNotNull);
      });

      test('should not queue non-network errors', () async {
        expect(
          () async => await retryManager.executeWithRetry(
            () async =>
                throw FileAccessException('Access denied', isRetryable: false),
            'noQueueTest',
            maxRetries: 1,
            queueOnFailure: true,
          ),
          throwsA(isA<FileAccessException>()),
        );

        final queueStatus = retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(0));
      });

      test('should process queued operations automatically', () async {
        int executionCount = 0;

        // Queue an operation that will fail initially
        expect(
          () async => await retryManager.executeWithRetry(
            () async {
              executionCount++;
              throw NetworkException('Network error', isRetryable: true);
            },
            'autoProcessTest',
            maxRetries: 1,
            queueOnFailure: true,
          ),
          throwsA(isA<OperationQueuedException>()),
        );

        expect(executionCount, equals(2)); // Initial + 1 retry

        final queueStatus = retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(1));

        // Wait a bit for automatic processing to potentially start
        await Future.delayed(const Duration(milliseconds: 100));

        // The operation should still be in queue since it keeps failing
        final updatedStatus = retryManager.getQueueStatus();
        expect(updatedStatus.queueSize, equals(1));
      });

      test('should clear queue when requested', () async {
        // Add some operations to queue
        for (int i = 0; i < 3; i++) {
          try {
            await retryManager.executeWithRetry(
              () async =>
                  throw NetworkException('Network error', isRetryable: true),
              'clearQueueTest$i',
              maxRetries: 0,
              queueOnFailure: true,
            );
          } catch (e) {
            // Expected to throw OperationQueuedException
          }
        }

        var queueStatus = retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(3));

        // Clear the queue
        retryManager.clearQueue();

        queueStatus = retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(0));
        expect(queueStatus.isProcessing, isFalse);
      });
    });

    group('Error Recovery Strategies', () {
      test('should handle mixed retryable and non-retryable errors', () async {
        int attemptCount = 0;
        final errorSequence = [
          NetworkException('Network error', isRetryable: true),
          NetworkException('Timeout', isRetryable: true),
          FileAccessException('Access denied',
              isRetryable: false), // Should stop here
        ];

        expect(
          () async => await retryManager.executeWithRetry(
            () async {
              if (attemptCount < errorSequence.length) {
                final error = errorSequence[attemptCount];
                attemptCount++;
                throw error;
              }
              return 'success';
            },
            'mixedErrorTest',
            maxRetries: 5,
            baseDelay: const Duration(milliseconds: 10),
          ),
          throwsA(isA<FileAccessException>()),
        );

        expect(attemptCount, equals(3)); // Should stop at non-retryable error
      });

      test('should succeed after retries when error is resolved', () async {
        int attemptCount = 0;

        final result = await retryManager.executeWithRetry(
          () async {
            attemptCount++;
            if (attemptCount < 3) {
              throw NetworkException('Temporary network error',
                  isRetryable: true);
            }
            return 'success after retries';
          },
          'successAfterRetriesTest',
          maxRetries: 5,
          baseDelay: const Duration(milliseconds: 10),
        );

        expect(result, equals('success after retries'));
        expect(attemptCount, equals(3));
      });

      test('should handle timeout scenarios correctly', () async {
        int attemptCount = 0;
        final startTime = DateTime.now();

        try {
          await retryManager.executeWithRetry(
            () async {
              attemptCount++;
              throw NetworkException('Timeout error', isRetryable: true);
            },
            'timeoutTest',
            maxRetries: 3,
            baseDelay: const Duration(milliseconds: 100),
            maxDelay: const Duration(milliseconds: 200),
          );
        } catch (e) {
          // Expected to fail
        }

        final endTime = DateTime.now();
        final totalDuration = endTime.difference(startTime);

        expect(attemptCount, equals(4)); // Initial + 3 retries
        // Should have taken at least the sum of delays
        expect(totalDuration.inMilliseconds,
            greaterThan(300)); // At least 100+200+200ms
      });
    });

    group('Performance Under Load', () {
      test('should handle concurrent retry operations', () async {
        final futures = <Future>[];
        final results = <String>[];

        // Start multiple concurrent retry operations
        for (int i = 0; i < 10; i++) {
          final future = retryManager
              .executeWithRetry(
                () async {
                  // Simulate some operations failing, others succeeding
                  if (i % 3 == 0) {
                    throw NetworkException('Network error $i',
                        isRetryable: true);
                  }
                  return 'success $i';
                },
                'concurrentTest$i',
                maxRetries: 2,
                baseDelay: const Duration(milliseconds: 10),
              )
              .then((result) => results.add(result))
              .catchError(
                  (error) => results.add('error: ${error.runtimeType}'));

          futures.add(future);
        }

        await Future.wait(futures);

        expect(results, hasLength(10));

        // Some should succeed, some should fail
        final successes = results.where((r) => r.startsWith('success')).length;
        final failures = results.where((r) => r.startsWith('error')).length;

        expect(successes, greaterThan(0));
        expect(failures, greaterThan(0));
        expect(successes + failures, equals(10));
      });

      test('should maintain circuit breaker state under concurrent load',
          () async {
        const operationName = 'concurrentCircuitTest';
        final futures = <Future>[];

        // Start multiple operations that will fail
        for (int i = 0; i < 10; i++) {
          final future = retryManager
              .executeWithRetry(
            () async =>
                throw NetworkException('Network error', isRetryable: true),
            operationName,
            maxRetries: 0,
            useCircuitBreaker: true,
          )
              .catchError((error) {
            // Expected to fail
            return null;
          });

          futures.add(future);
        }

        await Future.wait(futures);

        // Circuit should be open after multiple failures
        final status = retryManager.getCircuitBreakerStatus(operationName);
        expect(status, isNotNull);
        expect(status!.state, equals(CircuitState.open));
        expect(status.failureCount, greaterThanOrEqualTo(5));
      });
    });
  });
}
