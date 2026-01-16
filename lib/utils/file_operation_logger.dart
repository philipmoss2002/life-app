import '../services/log_service.dart';

/// Helper class for logging file operations with structured data
/// Simplifies logging file operations with performance tracking and audit trails
class FileOperationLogger {
  final LogService _logService = LogService();
  final Stopwatch _stopwatch = Stopwatch();

  String? _currentOperation;
  String? _currentUserIdentifier;
  String? _currentSyncId;
  String? _currentFileName;
  String? _currentS3Key;
  int? _currentFileSizeBytes;

  /// Start tracking a file operation
  void startOperation({
    required String operation,
    String? userIdentifier,
    String? syncId,
    String? fileName,
    String? s3Key,
    int? fileSizeBytes,
  }) {
    _currentOperation = operation;
    _currentUserIdentifier = userIdentifier;
    _currentSyncId = syncId;
    _currentFileName = fileName;
    _currentS3Key = s3Key;
    _currentFileSizeBytes = fileSizeBytes;
    _stopwatch.reset();
    _stopwatch.start();
  }

  /// Log successful completion of the operation
  void logSuccess({
    Map<String, dynamic>? additionalData,
  }) {
    _stopwatch.stop();

    if (_currentOperation != null) {
      // Log file operation
      _logService.logFileOperation(
        operation: _currentOperation!,
        outcome: 'success',
        userIdentifier: _currentUserIdentifier,
        syncId: _currentSyncId,
        fileName: _currentFileName,
        s3Key: _currentS3Key,
        fileSizeBytes: _currentFileSizeBytes,
        additionalData: additionalData,
      );

      // Log performance metric
      _logService.recordPerformanceMetric(
        operation: _currentOperation!,
        duration: _stopwatch.elapsed,
        userIdentifier: _currentUserIdentifier,
        resourceId: _currentS3Key ?? _currentSyncId,
        dataSizeBytes: _currentFileSizeBytes,
        success: true,
        additionalMetrics: additionalData,
      );
    }

    _reset();
  }

  /// Log failure of the operation
  void logFailure({
    required String errorMessage,
    String? errorCode,
    int? retryAttempt,
    Map<String, dynamic>? additionalData,
  }) {
    _stopwatch.stop();

    if (_currentOperation != null) {
      // Log file operation
      _logService.logFileOperation(
        operation: _currentOperation!,
        outcome: 'failure',
        userIdentifier: _currentUserIdentifier,
        syncId: _currentSyncId,
        fileName: _currentFileName,
        s3Key: _currentS3Key,
        fileSizeBytes: _currentFileSizeBytes,
        errorCode: errorCode,
        errorMessage: errorMessage,
        retryAttempt: retryAttempt,
        additionalData: additionalData,
      );

      // Log performance metric
      _logService.recordPerformanceMetric(
        operation: _currentOperation!,
        duration: _stopwatch.elapsed,
        userIdentifier: _currentUserIdentifier,
        resourceId: _currentS3Key ?? _currentSyncId,
        dataSizeBytes: _currentFileSizeBytes,
        success: false,
        additionalMetrics: {
          'errorCode': errorCode,
          'errorMessage': errorMessage,
          'retryAttempt': retryAttempt,
          ...?additionalData,
        },
      );
    }

    _reset();
  }

  /// Log an audit event for security-sensitive operations
  void logAuditEvent({
    required String eventType,
    required String action,
    String? userIdentifier,
    String? resourceId,
    String? outcome,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    _logService.logAuditEvent(
      eventType: eventType,
      action: action,
      userIdentifier: userIdentifier ?? _currentUserIdentifier,
      resourceId: resourceId ?? _currentS3Key ?? _currentSyncId,
      outcome: outcome,
      details: details,
      metadata: metadata,
    );
  }

  /// Get elapsed time for current operation
  Duration get elapsed => _stopwatch.elapsed;

  /// Check if an operation is currently being tracked
  bool get isTracking => _currentOperation != null && _stopwatch.isRunning;

  void _reset() {
    _currentOperation = null;
    _currentUserIdentifier = null;
    _currentSyncId = null;
    _currentFileName = null;
    _currentS3Key = null;
    _currentFileSizeBytes = null;
    _stopwatch.reset();
  }
}

/// Convenience wrapper for tracking file operations with automatic logging
class FileOperationTracker {
  final FileOperationLogger _logger = FileOperationLogger();
  final String operation;
  final String? userIdentifier;
  final String? syncId;
  final String? fileName;
  final String? s3Key;
  final int? fileSizeBytes;

  FileOperationTracker({
    required this.operation,
    this.userIdentifier,
    this.syncId,
    this.fileName,
    this.s3Key,
    this.fileSizeBytes,
  }) {
    _logger.startOperation(
      operation: operation,
      userIdentifier: userIdentifier,
      syncId: syncId,
      fileName: fileName,
      s3Key: s3Key,
      fileSizeBytes: fileSizeBytes,
    );
  }

  /// Execute an operation with automatic success/failure logging
  Future<T> track<T>(Future<T> Function() operation) async {
    try {
      final result = await operation();
      _logger.logSuccess();
      return result;
    } catch (e) {
      _logger.logFailure(
        errorMessage: e.toString(),
        errorCode: _extractErrorCode(e),
      );
      rethrow;
    }
  }

  /// Execute an operation with retry support and automatic logging
  Future<T> trackWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Exception? lastException;

    while (attempt < maxRetries) {
      try {
        final result = await operation();
        _logger.logSuccess(
          additionalData: {'totalAttempts': attempt + 1},
        );
        return result;
      } catch (e) {
        attempt++;
        lastException = e is Exception ? e : Exception(e.toString());

        if (attempt >= maxRetries) {
          _logger.logFailure(
            errorMessage: e.toString(),
            errorCode: _extractErrorCode(e),
            retryAttempt: attempt,
          );
          rethrow;
        }

        // Log retry attempt
        LogService().log(
          'Retry attempt $attempt for $operation: ${e.toString()}',
          level: LogLevel.warning,
        );

        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (1 << attempt)));
      }
    }

    throw lastException!;
  }

  String? _extractErrorCode(dynamic error) {
    final errorStr = error.toString();

    // Extract AWS error codes
    if (errorStr.contains('AccessDenied')) {
      return 'AccessDenied';
    }
    if (errorStr.contains('NoSuchKey')) {
      return 'NoSuchKey';
    }
    if (errorStr.contains('InvalidAccessKeyId')) {
      return 'InvalidAccessKeyId';
    }
    if (errorStr.contains('SignatureDoesNotMatch')) {
      return 'SignatureDoesNotMatch';
    }
    if (errorStr.contains('NetworkException')) {
      return 'NetworkException';
    }
    if (errorStr.contains('TimeoutException')) {
      return 'TimeoutException';
    }

    // Extract custom error codes
    if (errorStr.contains('UserPoolSubException')) {
      return 'UserPoolSubException';
    }
    if (errorStr.contains('FilePathGenerationException')) {
      return 'FilePathGenerationException';
    }
    if (errorStr.contains('FileMigrationException')) {
      return 'FileMigrationException';
    }

    return null;
  }
}
