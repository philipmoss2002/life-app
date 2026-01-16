import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/utils/file_operation_error_handler.dart';
import 'package:household_docs_app/utils/retry_manager.dart';
import 'dart:io';
import 'dart:async';

void main() {
  group('FileOperationErrorHandler', () {
    setUp(() {
      // Clear retry manager state before each test
      FileOperationErrorHandler.retryManager.clearCircuitBreakers();
      FileOperationErrorHandler.retryManager.clearQueue();
    });

    group('Error Classification', () {
      test('should classify SocketException as NetworkException', () {
        final socketError = const SocketException('Connection refused');

        final result =
            FileOperationErrorHandler.handleNetworkError(socketError);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Network connection failed'));
        expect(result.isRetryable, isTrue);
      });

      test('should classify TimeoutException as NetworkException', () {
        final timeoutError =
            TimeoutException('Request timeout', const Duration(seconds: 30));

        final result =
            FileOperationErrorHandler.handleNetworkError(timeoutError);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('Operation timed out'));
        expect(result.isRetryable, isTrue);
      });

      test(
          'should classify HttpException with 5xx as retryable NetworkException',
          () {
        final httpError = const HttpException('500 Internal Server Error');

        final result = FileOperationErrorHandler.handleNetworkError(httpError);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('HTTP error'));
        expect(result.isRetryable, isTrue);
      });

      test(
          'should classify HttpException with 429 as retryable NetworkException',
          () {
        final httpError = const HttpException('429 Too Many Requests');

        final result = FileOperationErrorHandler.handleNetworkError(httpError);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('HTTP error'));
        expect(result.isRetryable, isTrue);
      });

      test(
          'should classify HttpException with 4xx as non-retryable NetworkException',
          () {
        final httpError = const HttpException('404 Not Found');

        final result = FileOperationErrorHandler.handleNetworkError(httpError);

        expect(result, isA<NetworkException>());
        expect(result.message, contains('HTTP error'));
        expect(result.isRetryable, isFalse);
      });

      test('should classify FileSystemException as CustomFileSystemException',
          () {
        final fileError =
            const FileSystemException('File not found', '/path/to/file');

        final result =
            FileOperationErrorHandler.handleFileSystemError(fileError);

        expect(result, isA<CustomFileSystemException>());
        expect(result.message, contains('File system error'));
        expect(result.isRetryable, isFalse);
      });
    });

    group('Error Recovery Strategies', () {
      test('should handle retryable errors with exponential backoff', () async {
        int attemptCount = 0;
        final startTime = DateTime.now();

        final result = await FileOperationErrorHandler.executeWithRetry(
          () async {
            attemptCount++;
            if (attemptCount < 3) {
              throw const SocketException('Connection refused');
            }
            return 'success';
          },
          'testOperation',
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(seconds: 1),
        );

        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        expect(result, equals('success'));
        expect(attemptCount, equals(3));
        // Should have some delay due to exponential backoff
        expect(duration.inMilliseconds,
            greaterThan(200)); // At least 100ms + 200ms delays
      });

      test('should not retry non-retryable errors', () async {
        int attemptCount = 0;

        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async {
              attemptCount++;
              throw const FileSystemException('Access denied');
            },
            'testOperation',
            maxRetries: 3,
          ),
          throwsA(isA<CustomFileSystemException>()),
        );

        expect(attemptCount, equals(1)); // Should not retry
      });

      test('should respect max retry limit', () async {
        int attemptCount = 0;

        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async {
              attemptCount++;
              throw const SocketException('Connection refused');
            },
            'testOperation',
            maxRetries: 2,
            baseDelay: const Duration(milliseconds: 10),
          ),
          throwsA(isA<NetworkException>()),
        );

        expect(attemptCount, equals(3)); // Initial attempt + 2 retries
      });

      test('should handle mixed error types correctly', () async {
        int attemptCount = 0;

        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async {
              attemptCount++;
              switch (attemptCount) {
                case 1:
                  throw const SocketException(
                      'Connection refused'); // Retryable
                case 2:
                  throw TimeoutException(
                      'Timeout', const Duration(seconds: 30)); // Retryable
                case 3:
                  throw const FileSystemException(
                      'Access denied'); // Non-retryable
                default:
                  return 'success';
              }
            },
            'testOperation',
            maxRetries: 5,
            baseDelay: const Duration(milliseconds: 10),
          ),
          throwsA(isA<CustomFileSystemException>()),
        );

        expect(attemptCount, equals(3)); // Should stop at non-retryable error
      });
    });

    group('Circuit Breaker Integration', () {
      test('should use circuit breaker when enabled', () async {
        // Cause failures to open circuit breaker
        for (int i = 0; i < 5; i++) {
          try {
            await FileOperationErrorHandler.executeWithRetry(
              () async => throw const SocketException('Connection refused'),
              'testCircuitBreaker',
              maxRetries: 0,
              useCircuitBreaker: true,
            );
          } catch (e) {
            // Expected to fail
          }
        }

        // Circuit should now be open
        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async => 'success',
            'testCircuitBreaker',
            useCircuitBreaker: true,
          ),
          throwsA(isA<CircuitBreakerOpenException>()),
        );
      });

      test('should bypass circuit breaker when disabled', () async {
        // Cause failures that would normally open circuit breaker
        for (int i = 0; i < 5; i++) {
          try {
            await FileOperationErrorHandler.executeWithRetry(
              () async => throw const SocketException('Connection refused'),
              'testNoCircuitBreaker',
              maxRetries: 0,
              useCircuitBreaker: false,
            );
          } catch (e) {
            // Expected to fail
          }
        }

        // Should still work since circuit breaker is disabled
        final result = await FileOperationErrorHandler.executeWithRetry(
          () async => 'success',
          'testNoCircuitBreaker',
          useCircuitBreaker: false,
        );

        expect(result, equals('success'));
      });
    });

    group('Operation Queuing', () {
      test('should queue operations on network failure when enabled', () async {
        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async => throw const SocketException('Connection refused'),
            'testQueueing',
            maxRetries: 1,
            queueOnFailure: true,
          ),
          throwsA(isA<OperationQueuedException>()),
        );

        final queueStatus =
            FileOperationErrorHandler.retryManager.getQueueStatus();
        expect(queueStatus.queueSize, greaterThan(0));
      });

      test('should not queue operations when disabled', () async {
        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async => throw const SocketException('Connection refused'),
            'testNoQueueing',
            maxRetries: 1,
            queueOnFailure: false,
          ),
          throwsA(isA<NetworkException>()),
        );

        final queueStatus =
            FileOperationErrorHandler.retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(0));
      });

      test('should not queue non-network errors', () async {
        expect(
          () async => await FileOperationErrorHandler.executeWithRetry(
            () async => throw const FileSystemException('Access denied'),
            'testNoQueueAuth',
            maxRetries: 1,
            queueOnFailure: true,
          ),
          throwsA(isA<CustomFileSystemException>()),
        );

        final queueStatus =
            FileOperationErrorHandler.retryManager.getQueueStatus();
        expect(queueStatus.queueSize, equals(0));
      });
    });

    group('Error Message Handling', () {
      test('should provide meaningful error messages', () {
        final socketError = const SocketException('Connection refused');

        final result =
            FileOperationErrorHandler.handleNetworkError(socketError);

        expect(result.message, contains('Network connection failed'));
        expect(result.message, contains('Connection refused'));
      });

      test('should preserve original error information', () {
        final originalError = const SocketException('Original message');

        final result =
            FileOperationErrorHandler.handleNetworkError(originalError);

        expect(result.originalError, equals(originalError));
      });
    });

    group('Retry Behavior Validation', () {
      test('should calculate exponential backoff correctly', () async {
        final delays = <Duration>[];
        int attemptCount = 0;
        DateTime? lastAttemptTime;

        try {
          await FileOperationErrorHandler.executeWithRetry(
            () async {
              final currentTime = DateTime.now();
              attemptCount++;

              if (lastAttemptTime != null) {
                delays.add(currentTime.difference(lastAttemptTime!));
              }
              lastAttemptTime = currentTime;

              if (attemptCount <= 3) {
                throw const SocketException('Connection refused');
              }
              return 'success';
            },
            'testBackoff',
            maxRetries: 3,
            baseDelay: const Duration(milliseconds: 100),
            maxDelay: const Duration(seconds: 2),
          );
        } catch (e) {
          // May fail, that's ok for this test
        }

        expect(attemptCount, greaterThan(1));
        // Delays should generally increase (with some jitter)
        if (delays.length >= 2) {
          expect(delays[1].inMilliseconds,
              greaterThan(delays[0].inMilliseconds * 0.5));
        }
      });

      test('should respect max delay limit', () async {
        final delays = <Duration>[];
        int attemptCount = 0;
        DateTime? lastAttemptTime;

        try {
          await FileOperationErrorHandler.executeWithRetry(
            () async {
              final currentTime = DateTime.now();
              attemptCount++;

              if (lastAttemptTime != null) {
                delays.add(currentTime.difference(lastAttemptTime!));
              }
              lastAttemptTime = currentTime;

              throw const SocketException('Connection refused');
            },
            'testMaxDelay',
            maxRetries: 5,
            baseDelay: const Duration(milliseconds: 100),
            maxDelay: const Duration(milliseconds: 500),
          );
        } catch (e) {
          // Expected to fail
        }

        // All delays should be less than or equal to maxDelay + some tolerance for jitter
        for (final delay in delays) {
          expect(delay.inMilliseconds,
              lessThanOrEqualTo(600)); // 500ms + 100ms tolerance
        }
      });
    });
  });
}
