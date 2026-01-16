import 'dart:async';
import 'dart:math';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'file_operation_error_handler.dart' as error_handler;

/// Manages retry logic with exponential backoff and circuit breaker pattern
class RetryManager {
  static final RetryManager _instance = RetryManager._internal();
  factory RetryManager() => _instance;
  RetryManager._internal();

  // Circuit breaker state
  final Map<String, CircuitBreakerState> _circuitBreakers = {};

  // Operation queue for offline scenarios
  final List<QueuedOperation> _operationQueue = [];
  bool _isProcessingQueue = false;

  /// Execute operation with retry logic, exponential backoff, and circuit breaker
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    bool useCircuitBreaker = true,
    bool queueOnFailure = false,
  }) async {
    // Check circuit breaker state
    if (useCircuitBreaker && _isCircuitOpen(operationName)) {
      throw CircuitBreakerOpenException(
          'Circuit breaker is open for operation: $operationName');
    }

    int attempt = 0;
    Exception? lastError;

    while (attempt <= maxRetries) {
      try {
        final result = await operation();

        // Reset circuit breaker on success
        if (useCircuitBreaker) {
          _resetCircuitBreaker(operationName);
        }

        return result;
      } catch (error) {
        lastError = error is Exception ? error : Exception(error.toString());

        final handledException =
            error_handler.FileOperationErrorHandler.handleError(lastError);

        // Record failure for circuit breaker
        if (useCircuitBreaker) {
          _recordFailure(operationName);
        }

        // Don't retry if error is not retryable or we've exceeded max retries
        if (!handledException.isRetryable || attempt >= maxRetries) {
          // Queue operation if requested and it's a network error
          if (queueOnFailure &&
              handledException is error_handler.NetworkException) {
            await _queueOperation(operation, operationName);
            throw OperationQueuedException(
                'Operation queued due to network failure: ${handledException.message}');
          }

          throw handledException;
        }

        // Calculate delay with exponential backoff and jitter
        final delay = _calculateDelay(attempt, baseDelay, maxDelay);

        safePrint(
            '$operationName failed (attempt ${attempt + 1}/${maxRetries + 1}), '
            'retrying in ${delay.inMilliseconds}ms: ${handledException.message}');

        await Future.delayed(delay);
        attempt++;
      }
    }

    // This should never be reached, but just in case
    throw error_handler.FileOperationErrorHandler.handleError(
        lastError ?? Exception('Unknown error during retry operation'));
  }

  /// Calculate delay with exponential backoff and jitter
  Duration _calculateDelay(int attempt, Duration baseDelay, Duration maxDelay) {
    // Exponential backoff: baseDelay * 2^attempt
    final exponentialDelay = Duration(
        milliseconds: (baseDelay.inMilliseconds * pow(2, attempt)).toInt());

    // Cap at maxDelay
    final cappedDelay =
        exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

    // Add jitter (±25% of the delay)
    final jitterRange = (cappedDelay.inMilliseconds * 0.25).toInt();
    final jitter = Random().nextInt(jitterRange * 2) - jitterRange;

    final finalDelay = Duration(
        milliseconds: (cappedDelay.inMilliseconds + jitter)
            .clamp(baseDelay.inMilliseconds, maxDelay.inMilliseconds));

    return finalDelay;
  }

  /// Check if circuit breaker is open for an operation
  bool _isCircuitOpen(String operationName) {
    final state = _circuitBreakers[operationName];
    if (state == null) return false;

    // Check if circuit should transition from open to half-open
    if (state.state == CircuitState.open) {
      if (state.nextAttemptTime != null &&
          DateTime.now().isAfter(state.nextAttemptTime!)) {
        state.state = CircuitState.halfOpen;
        safePrint(
            'Circuit breaker for $operationName transitioned to half-open');
      }
    }

    return state.state == CircuitState.open;
  }

  /// Record a failure for circuit breaker logic
  void _recordFailure(String operationName) {
    final state = _circuitBreakers.putIfAbsent(
        operationName, () => CircuitBreakerState());

    state.failureCount++;
    state.lastFailureTime = DateTime.now();

    // Open circuit if failure threshold is exceeded
    if (state.failureCount >= state.failureThreshold &&
        state.state == CircuitState.closed) {
      state.state = CircuitState.open;
      state.nextAttemptTime = DateTime.now().add(state.timeout);
      safePrint(
          'Circuit breaker opened for $operationName after ${state.failureCount} failures');
    }
  }

  /// Reset circuit breaker on successful operation
  void _resetCircuitBreaker(String operationName) {
    final state = _circuitBreakers[operationName];
    if (state != null) {
      state.failureCount = 0;
      state.state = CircuitState.closed;
      state.lastFailureTime = null;
    }
  }

  /// Queue operation for later execution (offline scenarios)
  Future<void> _queueOperation<T>(
      Future<T> Function() operation, String operationName) async {
    final queuedOp = QueuedOperation<T>(
      operation: operation,
      operationName: operationName,
      queuedAt: DateTime.now(),
    );

    _operationQueue.add(queuedOp);
    safePrint(
        'Queued operation: $operationName (queue size: ${_operationQueue.length})');

    // Start processing queue if not already running
    if (!_isProcessingQueue) {
      _processQueue();
    }
  }

  /// Process queued operations
  Future<void> _processQueue() async {
    if (_isProcessingQueue || _operationQueue.isEmpty) return;

    _isProcessingQueue = true;
    safePrint(
        'Starting to process operation queue (${_operationQueue.length} operations)');

    while (_operationQueue.isNotEmpty) {
      final queuedOp = _operationQueue.first;

      try {
        // Try to execute the queued operation
        await queuedOp.operation();

        // Remove from queue on success
        _operationQueue.removeAt(0);
        safePrint(
            'Successfully executed queued operation: ${queuedOp.operationName}');
      } catch (error) {
        final handledException =
            error_handler.FileOperationErrorHandler.handleError(
                error is Exception ? error : Exception(error.toString()));

        // If it's still a network error, wait and try again later
        if (handledException is error_handler.NetworkException) {
          safePrint(
              'Queued operation ${queuedOp.operationName} still failing, will retry later');
          await Future.delayed(const Duration(minutes: 1));
          break; // Stop processing queue for now
        } else {
          // Remove non-retryable operations from queue
          _operationQueue.removeAt(0);
          safePrint(
              'Removed non-retryable operation from queue: ${queuedOp.operationName}');
        }
      }
    }

    _isProcessingQueue = false;

    // Schedule next queue processing if there are still operations
    if (_operationQueue.isNotEmpty) {
      Timer(const Duration(minutes: 5), _processQueue);
    }
  }

  /// Get current queue status
  QueueStatus getQueueStatus() {
    return QueueStatus(
      queueSize: _operationQueue.length,
      isProcessing: _isProcessingQueue,
      oldestOperation:
          _operationQueue.isNotEmpty ? _operationQueue.first.queuedAt : null,
    );
  }

  /// Get circuit breaker status for an operation
  CircuitBreakerStatus? getCircuitBreakerStatus(String operationName) {
    final state = _circuitBreakers[operationName];
    if (state == null) return null;

    return CircuitBreakerStatus(
      operationName: operationName,
      state: state.state,
      failureCount: state.failureCount,
      lastFailureTime: state.lastFailureTime,
      nextAttemptTime: state.nextAttemptTime,
    );
  }

  /// Clear all circuit breakers (for testing or manual reset)
  void clearCircuitBreakers() {
    _circuitBreakers.clear();
    safePrint('All circuit breakers cleared');
  }

  /// Clear operation queue (for testing or manual reset)
  void clearQueue() {
    _operationQueue.clear();
    _isProcessingQueue = false;
    safePrint('Operation queue cleared');
  }
}

/// Circuit breaker states
enum CircuitState { closed, open, halfOpen }

/// Circuit breaker state management
class CircuitBreakerState {
  CircuitState state = CircuitState.closed;
  int failureCount = 0;
  int failureThreshold = 5; // Open circuit after 5 failures
  Duration timeout =
      const Duration(minutes: 1); // Wait 1 minute before trying again
  DateTime? lastFailureTime;
  DateTime? nextAttemptTime;
}

/// Queued operation for offline scenarios
class QueuedOperation<T> {
  final Future<T> Function() operation;
  final String operationName;
  final DateTime queuedAt;

  QueuedOperation({
    required this.operation,
    required this.operationName,
    required this.queuedAt,
  });
}

/// Queue status information
class QueueStatus {
  final int queueSize;
  final bool isProcessing;
  final DateTime? oldestOperation;

  QueueStatus({
    required this.queueSize,
    required this.isProcessing,
    this.oldestOperation,
  });
}

/// Circuit breaker status information
class CircuitBreakerStatus {
  final String operationName;
  final CircuitState state;
  final int failureCount;
  final DateTime? lastFailureTime;
  final DateTime? nextAttemptTime;

  CircuitBreakerStatus({
    required this.operationName,
    required this.state,
    required this.failureCount,
    this.lastFailureTime,
    this.nextAttemptTime,
  });
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException extends error_handler.FileOperationException {
  const CircuitBreakerOpenException(String message)
      : super(message, isRetryable: false);

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}

/// Exception thrown when operation is queued for later execution
class OperationQueuedException extends error_handler.FileOperationException {
  const OperationQueuedException(String message)
      : super(message, isRetryable: false);

  @override
  String toString() => 'OperationQueuedException: $message';
}
