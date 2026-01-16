import 'dart:async';
import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'retry_manager.dart';

/// Comprehensive error handler for file operations with User Pool authentication
class FileOperationErrorHandler {
  static final RetryManager _retryManager = RetryManager();

  /// Execute operation with retry logic, exponential backoff, and circuit breaker
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    bool useCircuitBreaker = true,
    bool queueOnFailure = false,
  }) async {
    return await _retryManager.executeWithRetry(
      operation,
      operationName,
      maxRetries: maxRetries,
      baseDelay: baseDelay,
      maxDelay: maxDelay,
      useCircuitBreaker: useCircuitBreaker,
      queueOnFailure: queueOnFailure,
    );
  }

  /// Get retry manager instance for advanced operations
  static RetryManager get retryManager => _retryManager;

  static FileOperationException handleAuthenticationError(Exception error) {
    if (error is AuthException) {
      switch (error.recoverySuggestion) {
        case 'Sign in again':
          return UserPoolAuthenticationException(
            'User authentication expired. Please sign in again.',
            originalError: error,
            requiresReauth: true,
          );
        case 'Check network connection':
          return NetworkException(
            'Network error during authentication. Check your connection.',
            originalError: error,
            isRetryable: true,
          );
        default:
          return UserPoolAuthenticationException(
            'Authentication failed: ${error.message}',
            originalError: error,
            requiresReauth: true,
          );
      }
    }

    return FileOperationException(
      'Unknown authentication error occurred',
      originalError: error,
    );
  }

  /// Handle S3 storage operation errors
  static FileOperationException handleStorageError(Exception error) {
    if (error is StorageException) {
      switch (error.recoverySuggestion) {
        case 'Check network connection':
          return NetworkException(
            'Network error during storage operation: ${error.message}',
            originalError: error,
            isRetryable: true,
          );
        case 'Check credentials':
          return UserPoolAuthenticationException(
            'Invalid credentials for storage access: ${error.message}',
            originalError: error,
            requiresReauth: true,
          );
        case 'Check file permissions':
          return FileAccessException(
            'Insufficient permissions for file operation: ${error.message}',
            originalError: error,
            isRetryable: false,
          );
        default:
          return StorageOperationException(
            'Storage operation failed: ${error.message}',
            originalError: error,
            isRetryable: _isRetryableStorageError(error),
          );
      }
    }

    return FileOperationException(
      'Unknown storage error occurred',
      originalError: error,
    );
  }

  /// Handle network-related errors
  static FileOperationException handleNetworkError(Exception error) {
    if (error is SocketException) {
      return NetworkException(
        'Network connection failed: ${error.message}',
        originalError: error,
        isRetryable: true,
      );
    }

    if (error is TimeoutException) {
      return NetworkException(
        'Operation timed out: ${error.message ?? 'Request timeout'}',
        originalError: error,
        isRetryable: true,
      );
    }

    if (error is HttpException) {
      final isRetryable = error.message.contains('5') || // 5xx server errors
          error.message.contains('429'); // Rate limiting

      return NetworkException(
        'HTTP error: ${error.message}',
        originalError: error,
        isRetryable: isRetryable,
      );
    }

    return NetworkException(
      'Network error occurred',
      originalError: error,
      isRetryable: true,
    );
  }

  /// Handle file system errors
  static FileOperationException handleFileSystemError(Exception error) {
    if (error is FileSystemException) {
      return CustomFileSystemException(
        'File system error: ${error.message}',
        originalError: error,
        isRetryable: false,
      );
    }

    return FileOperationException(
      'Unknown file system error occurred',
      originalError: error,
    );
  }

  /// Main error handling dispatcher
  static FileOperationException handleError(Exception error) {
    // Handle authentication errors first
    if (error is AuthException) {
      return handleAuthenticationError(error);
    }

    // Handle storage-specific errors
    if (error is StorageException) {
      return handleStorageError(error);
    }

    // Handle network errors
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return handleNetworkError(error);
    }

    // Handle file system errors
    if (error is FileSystemException) {
      return handleFileSystemError(error);
    }

    // Handle our custom exceptions
    if (error is FileOperationException) {
      return error;
    }

    // Default fallback
    return FileOperationException(
      'Unexpected error occurred: ${error.toString()}',
      originalError: error,
    );
  }

  /// Check if a storage error is retryable
  static bool _isRetryableStorageError(StorageException error) {
    final message = error.message.toLowerCase();

    // Retryable conditions
    if (message.contains('timeout') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('throttl') ||
        message.contains('rate limit') ||
        message.contains('service unavailable') ||
        message.contains('internal server error')) {
      return true;
    }

    // Non-retryable conditions
    if (message.contains('not found') ||
        message.contains('access denied') ||
        message.contains('forbidden') ||
        message.contains('unauthorized') ||
        message.contains('invalid') ||
        message.contains('malformed')) {
      return false;
    }

    // Default to retryable for unknown errors
    return true;
  }
}

/// Base exception class for file operations
class FileOperationException implements Exception {
  final String message;
  final Exception? originalError;
  final bool isRetryable;

  const FileOperationException(
    this.message, {
    this.originalError,
    this.isRetryable = false,
  });

  @override
  String toString() => 'FileOperationException: $message';
}

/// Exception for User Pool authentication failures
class UserPoolAuthenticationException extends FileOperationException {
  final bool requiresReauth;

  const UserPoolAuthenticationException(
    String message, {
    Exception? originalError,
    this.requiresReauth = false,
  }) : super(message, originalError: originalError, isRetryable: false);

  @override
  String toString() => 'UserPoolAuthenticationException: $message';
}

/// Exception for network-related errors
class NetworkException extends FileOperationException {
  const NetworkException(
    String message, {
    Exception? originalError,
    bool isRetryable = true,
  }) : super(message, originalError: originalError, isRetryable: isRetryable);

  @override
  String toString() => 'NetworkException: $message';
}

/// Exception for file access permission errors
class FileAccessException extends FileOperationException {
  const FileAccessException(
    String message, {
    Exception? originalError,
    bool isRetryable = false,
  }) : super(message, originalError: originalError, isRetryable: isRetryable);

  @override
  String toString() => 'FileAccessException: $message';
}

/// Exception for storage operation failures
class StorageOperationException extends FileOperationException {
  const StorageOperationException(
    String message, {
    Exception? originalError,
    bool isRetryable = true,
  }) : super(message, originalError: originalError, isRetryable: isRetryable);

  @override
  String toString() => 'StorageOperationException: $message';
}

/// Exception for file not found errors
class FileNotFoundException extends FileOperationException {
  final String? filePath;

  const FileNotFoundException(
    String message, {
    Exception? originalError,
    this.filePath,
  }) : super(message, originalError: originalError, isRetryable: false);

  @override
  String toString() => 'FileNotFoundException: $message';
}

/// Exception for file system errors
class CustomFileSystemException extends FileOperationException {
  const CustomFileSystemException(
    String message, {
    Exception? originalError,
    bool isRetryable = false,
  }) : super(message, originalError: originalError, isRetryable: isRetryable);

  @override
  String toString() => 'CustomFileSystemException: $message';
}

/// Exception for User Pool sub validation errors
class UserPoolSubException extends FileOperationException {
  final String? invalidSub;

  const UserPoolSubException(
    String message, {
    Exception? originalError,
    this.invalidSub,
  }) : super(message, originalError: originalError, isRetryable: false);

  @override
  String toString() => 'UserPoolSubException: $message';
}

/// Exception for file path generation errors
class FilePathGenerationException extends FileOperationException {
  final String? invalidPath;

  const FilePathGenerationException(
    String message, {
    Exception? originalError,
    this.invalidPath,
  }) : super(message, originalError: originalError, isRetryable: false);

  @override
  String toString() => 'FilePathGenerationException: $message';
}
