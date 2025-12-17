import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';

/// Information about a document in error state
class DocumentError {
  final String documentId;
  final String errorMessage;
  final DateTime errorTime;
  final int retryCount;
  final String? lastOperation;
  final Object? originalError;

  DocumentError({
    required this.documentId,
    required this.errorMessage,
    required this.errorTime,
    required this.retryCount,
    this.lastOperation,
    this.originalError,
  });

  /// Get a user-friendly error message
  String getUserFriendlyMessage() {
    if (errorMessage.toLowerCase().contains('network')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    } else if (errorMessage.toLowerCase().contains('authentication') ||
        errorMessage.toLowerCase().contains('unauthorized')) {
      return 'Authentication issue. Please sign in again.';
    } else if (errorMessage.toLowerCase().contains('version conflict')) {
      return 'Document was modified on another device. Please resolve the conflict.';
    } else if (errorMessage.toLowerCase().contains('not found')) {
      return 'Document not found on server. It may have been deleted.';
    } else if (errorMessage.toLowerCase().contains('storage') ||
        errorMessage.toLowerCase().contains('space')) {
      return 'Storage issue. Please check available space and try again.';
    } else {
      return 'Sync failed. Please try again later or contact support.';
    }
  }

  /// Check if the error is recoverable
  bool get isRecoverable {
    final lowerError = errorMessage.toLowerCase();

    // Non-recoverable errors
    if (lowerError.contains('not found') ||
        lowerError.contains('deleted') ||
        lowerError.contains('invalid document') ||
        lowerError.contains('permission denied')) {
      return false;
    }

    // Recoverable errors
    return lowerError.contains('network') ||
        lowerError.contains('timeout') ||
        lowerError.contains('server error') ||
        lowerError.contains('authentication') ||
        lowerError.contains('storage') ||
        lowerError.contains('connection') ||
        lowerError.contains('refused');
  }

  /// Get suggested recovery action
  String get recoveryAction {
    final lowerError = errorMessage.toLowerCase();

    if (lowerError.contains('network') || lowerError.contains('timeout')) {
      return 'Check internet connection and retry';
    } else if (lowerError.contains('authentication') ||
        lowerError.contains('unauthorized')) {
      return 'Sign in again';
    } else if (lowerError.contains('storage') || lowerError.contains('space')) {
      return 'Free up storage space';
    } else if (lowerError.contains('version conflict')) {
      return 'Resolve document conflict';
    } else if (!isRecoverable) {
      return 'Contact support';
    } else {
      return 'Retry operation';
    }
  }
}

/// Manages documents that are in error state after failed sync operations
class ErrorStateManager {
  static final ErrorStateManager _instance = ErrorStateManager._internal();
  factory ErrorStateManager() => _instance;
  ErrorStateManager._internal();

  final Map<String, DocumentError> _errorDocuments = {};
  final Map<String, int> _retryAttempts = {};

  /// Mark a document as being in error state
  void markDocumentError(
    String documentId,
    String errorMessage, {
    int retryCount = 0,
    String? lastOperation,
    Object? originalError,
  }) {
    final documentError = DocumentError(
      documentId: documentId,
      errorMessage: errorMessage,
      errorTime: DateTime.now(),
      retryCount: retryCount,
      lastOperation: lastOperation,
      originalError: originalError,
    );

    _errorDocuments[documentId] = documentError;
    _retryAttempts[documentId] = retryCount;

    safePrint('Document $documentId marked as error: $errorMessage');
    safePrint(
        'User-friendly message: ${documentError.getUserFriendlyMessage()}');
    safePrint('Recovery action: ${documentError.recoveryAction}');
  }

  /// Check if a document is in error state
  bool isDocumentInError(String documentId) {
    return _errorDocuments.containsKey(documentId);
  }

  /// Get error information for a document
  DocumentError? getDocumentError(String documentId) {
    return _errorDocuments[documentId];
  }

  /// Get all documents in error state
  List<DocumentError> getAllErrorDocuments() {
    return _errorDocuments.values.toList();
  }

  /// Get documents with recoverable errors
  List<DocumentError> getRecoverableErrors() {
    return _errorDocuments.values
        .where((error) => error.isRecoverable)
        .toList();
  }

  /// Get documents with non-recoverable errors
  List<DocumentError> getNonRecoverableErrors() {
    return _errorDocuments.values
        .where((error) => !error.isRecoverable)
        .toList();
  }

  /// Clear error state for a document (when successfully recovered)
  void clearDocumentError(String documentId) {
    _errorDocuments.remove(documentId);
    _retryAttempts.remove(documentId);
    safePrint('Error state cleared for document $documentId');
  }

  /// Clear all error states
  void clearAllErrors() {
    final count = _errorDocuments.length;
    _errorDocuments.clear();
    _retryAttempts.clear();
    safePrint('Cleared error state for $count documents');
  }

  /// Increment retry count for a document
  void incrementRetryCount(String documentId) {
    _retryAttempts[documentId] = (_retryAttempts[documentId] ?? 0) + 1;
  }

  /// Get retry count for a document
  int getRetryCount(String documentId) {
    return _retryAttempts[documentId] ?? 0;
  }

  /// Check if a document has exceeded max retries
  bool hasExceededMaxRetries(String documentId, {int maxRetries = 5}) {
    return getRetryCount(documentId) >= maxRetries;
  }

  /// Attempt to recover a document from error state
  /// Returns true if recovery should be attempted, false otherwise
  bool canAttemptRecovery(String documentId) {
    final error = _errorDocuments[documentId];
    if (error == null) {
      return false; // No error to recover from
    }

    if (!error.isRecoverable) {
      safePrint(
          'Document $documentId has non-recoverable error: ${error.errorMessage}');
      return false;
    }

    // Check if enough time has passed since last error (exponential backoff)
    final timeSinceError = DateTime.now().difference(error.errorTime);
    final minWaitTime =
        Duration(seconds: (1 << error.retryCount).clamp(1, 300)); // 1s to 5min

    if (timeSinceError < minWaitTime) {
      safePrint(
          'Document $documentId: waiting ${minWaitTime.inSeconds - timeSinceError.inSeconds}s before retry');
      return false;
    }

    return true;
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    final errors = _errorDocuments.values.toList();
    final recoverable = errors.where((e) => e.isRecoverable).length;
    final nonRecoverable = errors.where((e) => !e.isRecoverable).length;

    // Group errors by type
    final errorTypes = <String, int>{};
    for (final error in errors) {
      final type = _categorizeError(error.errorMessage);
      errorTypes[type] = (errorTypes[type] ?? 0) + 1;
    }

    return {
      'totalErrors': errors.length,
      'recoverableErrors': recoverable,
      'nonRecoverableErrors': nonRecoverable,
      'errorTypes': errorTypes,
      'oldestError': errors.isEmpty
          ? null
          : errors
              .map((e) => e.errorTime)
              .reduce((a, b) => a.isBefore(b) ? a : b),
      'newestError': errors.isEmpty
          ? null
          : errors
              .map((e) => e.errorTime)
              .reduce((a, b) => a.isAfter(b) ? a : b),
    };
  }

  /// Categorize error for statistics
  String _categorizeError(String errorMessage) {
    final lower = errorMessage.toLowerCase();

    if (lower.contains('network') || lower.contains('timeout')) {
      return 'Network';
    } else if (lower.contains('authentication') ||
        lower.contains('unauthorized')) {
      return 'Authentication';
    } else if (lower.contains('version conflict')) {
      return 'Version Conflict';
    } else if (lower.contains('not found')) {
      return 'Not Found';
    } else if (lower.contains('storage') || lower.contains('space')) {
      return 'Storage';
    } else if (lower.contains('server error')) {
      return 'Server Error';
    } else {
      return 'Other';
    }
  }

  /// Get documents that are ready for retry
  List<String> getDocumentsReadyForRetry() {
    final readyDocuments = <String>[];

    for (final documentId in _errorDocuments.keys) {
      if (canAttemptRecovery(documentId)) {
        readyDocuments.add(documentId);
      }
    }

    return readyDocuments;
  }

  /// Update document sync state to error in the document model
  Document markDocumentSyncError(Document document, String errorMessage) {
    // Mark the document error in our manager
    markDocumentError(
      document.id,
      errorMessage,
      retryCount: getRetryCount(document.id),
    );

    // Return document with error sync state
    return document.copyWith(
      syncState: SyncState.error.toJson(),
      lastModified: TemporalDateTime.now(),
    );
  }

  /// Create a recovery plan for all error documents
  Map<String, List<String>> createRecoveryPlan() {
    final plan = <String, List<String>>{
      'immediate': <String>[],
      'delayed': <String>[],
      'manual': <String>[],
      'unrecoverable': <String>[],
    };

    for (final entry in _errorDocuments.entries) {
      final documentId = entry.key;
      final error = entry.value;

      if (!error.isRecoverable) {
        plan['unrecoverable']!.add(documentId);
      } else if (error.errorMessage
          .toLowerCase()
          .contains('version conflict')) {
        plan['manual']!.add(documentId);
      } else if (canAttemptRecovery(documentId)) {
        plan['immediate']!.add(documentId);
      } else {
        plan['delayed']!.add(documentId);
      }
    }

    return plan;
  }
}
