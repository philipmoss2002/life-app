import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/utils/retry_manager.dart';
import 'package:household_docs_app/utils/file_operation_error_handler.dart';

void main() {
  group('RetryManager', () {
    late RetryManager retryManager;

    setUp(() {
      retryManager = RetryManager();
      retryManager.clearCircuitBreakers();
      retryManager.clearQueue();
    });

    test('should execute operation successfully on first try', () async {
      int callCount = 0;

      final result = await retryManager.executeWithRetry(
        () async {
          callCount++;
          return 'success';
        },
        'testOperation',
      );

      expect(result, equals('success'));
      expect(callCount, equals(1));
    });

    test('should retry on retryable errors', () async {
      int callCount = 0;

      final result = await retryManager.executeWithRetry(
        () async {
          callCount++;
          if (callCount < 3) {
            throw NetworkException('Network error', isRetryable: true);
          }
          return 'success';
        },
        'testOperation',
        maxRetries: 3,
        baseDelay: Duration(milliseconds: 10),
      );

      expect(result, equals('success'));
      expect(callCount, equals(3));
    });

    test('should not retry on non-retryable errors', () async {
      int callCount = 0;

      expect(
        () async => await retryManager.executeWithRetry(
          () async {
            callCount++;
            throw FileAccessException('Access denied', isRetryable: false);
          },
          'testOperation',
          maxRetries: 3,
        ),
        throwsA(isA<FileAccessException>()),
      );

      expect(callCount, equals(1));
    });

    test('should open circuit breaker after threshold failures', () async {
      int callCount = 0;

      // Cause failures to open circuit breaker
      for (int i = 0; i < 5; i++) {
        try {
          await retryManager.executeWithRetry(
            () async {
              callCount++;
              throw NetworkException('Network error', isRetryable: true);
            },
            'testOperation',
            maxRetries: 0, // Don't retry within the operation
            useCircuitBreaker: true,
          );
        } catch (e) {
          // Expected to fail
        }
      }

      // Circuit should now be open
      expect(
        () async => await retryManager.executeWithRetry(
          () async => 'success',
          'testOperation',
          useCircuitBreaker: true,
        ),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('should provide queue status', () {
      final status = retryManager.getQueueStatus();

      expect(status.queueSize, equals(0));
      expect(status.isProcessing, equals(false));
      expect(status.oldestOperation, isNull);
    });

    test('should provide circuit breaker status', () {
      final status =
          retryManager.getCircuitBreakerStatus('nonExistentOperation');
      expect(status, isNull);
    });

    test('should clear circuit breakers', () {
      retryManager.clearCircuitBreakers();
      // Should not throw
    });

    test('should clear operation queue', () {
      retryManager.clearQueue();
      // Should not throw
    });
  });
}
