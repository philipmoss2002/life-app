import 'dart:async';
import 'dart:math';
import 'package:amplify_flutter/amplify_flutter.dart';

/// Exception types that should trigger retries
enum RetryableErrorType {
  network,
  authentication,
  serverError,
  timeout,
}

/// Configuration for retry behavior
class RetryConfig {
  final int maxRetries;
  final Duration baseDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 5,
    this.baseDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 16),
    this.useJitter = true,
  });
}

/// Manages retry logic with exponential backoff for network operations
class RetryManager {
  static const RetryConfig _defaultConfig = RetryConfig();
  final Random _random = Random();

  /// Execute an operation with retry logic and exponential backoff
  /// Returns the result of the operation if successful
  /// Throws the last exception if all retries are exhausted
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    RetryConfig config = _defaultConfig,
    bool Function(Object error)? shouldRetry,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt <= config.maxRetries) {
      try {
        return await operation();
      } catch (error) {
        lastError = error;
        attempt++;

        // Check if we should retry this error
        if (!_shouldRetryError(error, shouldRetry)) {
          safePrint('Error is not retryable, failing immediately: $error');
          rethrow;
        }

        // Check if we've exhausted retries
        if (attempt > config.maxRetries) {
          safePrint('Max retries ($config.maxRetries) exhausted for operation');
          rethrow;
        }

        // Calculate delay with exponential backoff and jitter
        final delay = _calculateDelay(attempt, config);
        safePrint('Operation failed (attempt $attempt/${config.maxRetries}), '
            'retrying in ${delay.inMilliseconds}ms: $error');

        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw lastError ?? Exception('Unknown error during retry operation');
  }

  /// Check if an error should trigger a retry
  bool _shouldRetryError(Object error, bool Function(Object)? customCheck) {
    // Use custom check if provided
    if (customCheck != null) {
      return customCheck(error);
    }

    // Default retry logic for common error types
    return _isNetworkError(error) ||
        _isServerError(error) ||
        _isTimeoutError(error);
  }

  /// Check if error is a network-related error
  bool _isNetworkError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('socket') ||
        errorString.contains('dns');
  }

  /// Check if error is a server error (5xx)
  bool _isServerError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('server error') ||
        errorString.contains('internal server error') ||
        errorString.contains('service unavailable') ||
        errorString.contains('bad gateway') ||
        errorString.contains('gateway timeout') ||
        errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504');
  }

  /// Check if error is a timeout error
  bool _isTimeoutError(Object error) {
    if (error is TimeoutException) {
      return true;
    }
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') || errorString.contains('timed out');
  }

  /// Check if error is an authentication error
  bool _isAuthenticationError(Object error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('unauthorized') ||
        errorString.contains('authentication') ||
        errorString.contains('token') ||
        errorString.contains('401') ||
        errorString.contains('403') ||
        errorString.contains('invalid credentials');
  }

  /// Calculate delay with exponential backoff and optional jitter
  Duration _calculateDelay(int attempt, RetryConfig config) {
    // Calculate exponential backoff: baseDelay * (backoffMultiplier ^ (attempt - 1))
    final exponentialDelay = config.baseDelay.inMilliseconds *
        pow(config.backoffMultiplier, attempt - 1);

    // Cap at maximum delay
    final cappedDelay = min(exponentialDelay, config.maxDelay.inMilliseconds);

    // Add jitter to prevent thundering herd
    final finalDelay = config.useJitter
        ? _addJitter(cappedDelay.toInt())
        : cappedDelay.toInt();

    return Duration(milliseconds: finalDelay);
  }

  /// Add jitter to delay to prevent thundering herd problem
  int _addJitter(int delayMs) {
    // Add random jitter of ±25% of the delay
    final jitterRange = (delayMs * 0.25).toInt();
    final jitter = _random.nextInt(jitterRange * 2) - jitterRange;
    return max(0, delayMs + jitter);
  }

  /// Get retry configuration for network operations
  static RetryConfig get networkRetryConfig => const RetryConfig(
        maxRetries: 5,
        baseDelay: Duration(seconds: 1),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 16),
        useJitter: true,
      );

  /// Get retry configuration for authentication operations
  static RetryConfig get authRetryConfig => const RetryConfig(
        maxRetries: 3,
        baseDelay: Duration(seconds: 2),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 8),
        useJitter: true,
      );

  /// Get retry configuration for file operations
  static RetryConfig get fileRetryConfig => const RetryConfig(
        maxRetries: 3,
        baseDelay: Duration(seconds: 2),
        backoffMultiplier: 2.0,
        maxDelay: Duration(seconds: 8),
        useJitter: true,
      );

  /// Public method for testing error classification
  bool isNetworkError(Object error) => _isNetworkError(error);

  /// Public method for testing timeout error classification
  bool isTimeoutError(Object error) => _isTimeoutError(error);
}
