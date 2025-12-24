import '../models/Document.dart';
import '../models/sync_event.dart';
import 'package:uuid/uuid.dart';
import 'log_service.dart' as app_log;
import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Enhanced error handler for sync operations that references documents by sync identifier
class SyncErrorHandler {
  static final SyncErrorHandler _instance = SyncErrorHandler._internal();
  factory SyncErrorHandler() => _instance;
  SyncErrorHandler._internal();

  final app_log.LogService _logService = app_log.LogService();

  /// Create a standardized error message that references the document by sync identifier
  String createErrorMessage(Document document, String operation, String error) {
    final syncIdRef = 'syncId: ${document.syncId}';

    return 'Failed to $operation document "${document.title}" ($syncIdRef): $error';
  }

  /// Create a sync event for an error with sync identifier included
  LocalSyncEvent createErrorEvent(
    Document document,
    String operation,
    String error, {
    Map<String, dynamic>? additionalMetadata,
  }) {
    final metadata = <String, dynamic>{
      'operation': operation,
      'documentTitle': document.title,
      'version': document.version,
      'error': error,
      ...?additionalMetadata,
    };

    return LocalSyncEvent(
      id: const Uuid().v4(),
      eventType: 'sync_error',
      entityType: 'document',
      entityId: document.syncId,
      syncId: document.syncId,
      message: createErrorMessage(document, operation, error),
      timestamp: amplify_core.TemporalDateTime.now(),
      metadata: metadata,
    );
  }

  /// Log an error with sync identifier context
  void logError(Document document, String operation, String error) {
    final message = createErrorMessage(document, operation, error);
    _logService.log(message, level: app_log.LogLevel.error);
  }

  /// Log a warning with sync identifier context
  void logWarning(Document document, String operation, String warning) {
    final syncIdRef = 'syncId: ${document.syncId}';

    final message =
        'Warning during $operation for document "${document.title}" ($syncIdRef): $warning';
    _logService.log(message, level: app_log.LogLevel.warning);
  }

  /// Create a user-friendly error message for UI display
  String createUserFriendlyMessage(
      Document document, String operation, String error) {
    final docRef =
        document.title.isNotEmpty ? document.title : 'Untitled Document';

    switch (operation.toLowerCase()) {
      case 'upload':
        return 'Failed to upload "$docRef". Please check your internet connection and try again.';
      case 'update':
        return 'Failed to update "$docRef". The document may have been modified on another device.';
      case 'delete':
        return 'Failed to delete "$docRef". Please try again.';
      case 'download':
        return 'Failed to download "$docRef". Please check your internet connection.';
      default:
        return 'Failed to sync "$docRef". Please try again.';
    }
  }

  /// Determine if an error is retryable based on the error message
  bool isRetryableError(String error) {
    final errorLower = error.toLowerCase();

    // Network-related errors are retryable
    if (errorLower.contains('network') ||
        errorLower.contains('connection') ||
        errorLower.contains('timeout') ||
        errorLower.contains('unreachable')) {
      return true;
    }

    // Temporary server errors are retryable
    if (errorLower.contains('500') ||
        errorLower.contains('502') ||
        errorLower.contains('503') ||
        errorLower.contains('504')) {
      return true;
    }

    // Authentication errors might be retryable after token refresh
    if (errorLower.contains('unauthorized') || errorLower.contains('token')) {
      return true;
    }

    // Validation errors and conflicts are not retryable
    if (errorLower.contains('validation') ||
        errorLower.contains('conflict') ||
        errorLower.contains('not found') ||
        errorLower.contains('duplicate')) {
      return false;
    }

    // Default to retryable for unknown errors
    return true;
  }

  /// Extract sync identifier from error context for logging
  String extractSyncIdFromContext(Map<String, dynamic>? context) {
    if (context == null) return 'unknown';

    // Try to get sync identifier from various possible keys
    return context['syncId']?.toString() ??
        context['sync_id']?.toString() ??
        context['documentSyncId']?.toString() ??
        context['entityId']?.toString() ??
        'unknown';
  }
}
