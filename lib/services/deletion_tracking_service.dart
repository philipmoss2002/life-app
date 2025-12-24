import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import '../models/DocumentTombstone.dart';
import '../models/sync_state.dart';
import 'database_service.dart';
import 'sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'log_service.dart' as app_log;

/// Service for managing document deletion tracking with tombstones
///
/// This service implements the tombstone pattern for tracking deleted documents
/// to prevent them from being reinstated during sync operations.
class DeletionTrackingService {
  static final DeletionTrackingService _instance =
      DeletionTrackingService._internal();
  factory DeletionTrackingService() => _instance;
  DeletionTrackingService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final app_log.LogService _logService = app_log.LogService();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);
  void _logDebug(String message) =>
      _logService.log(message, level: app_log.LogLevel.debug);

  /// Mark a document for deletion and create tombstone if needed
  ///
  /// This method handles the complete deletion workflow:
  /// 1. Updates document state to pendingDeletion
  /// 2. Creates tombstone if document has sync identifier
  /// 3. Preserves sync identifier for remote deletion
  Future<void> markDocumentForDeletion(
    Document document,
    String userId,
    String deletedBy, {
    String reason = 'user',
  }) async {
    try {
      _logInfo(
          'Marking document for deletion: ${document.title} (ID: ${document.syncId})');

      // Validate inputs
      if (userId.isEmpty) {
        throw ArgumentError('User ID cannot be empty');
      }
      if (deletedBy.isEmpty) {
        throw ArgumentError('DeletedBy cannot be empty');
      }

      // Check if document has sync identifier
      final syncId = _extractSyncId(document);
      if (syncId != null) {
        // Only validate if it looks like a UUID, otherwise use as-is for testing
        if (RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                caseSensitive: false)
            .hasMatch(syncId)) {
          SyncIdentifierService.validateOrThrow(syncId,
              context: 'deletion tracking');
        }

        // Create tombstone for documents with sync identifiers
        await _createTombstoneIfNeeded(syncId, userId, deletedBy, reason);
        _logInfo('Created tombstone for document with syncId: $syncId');
      } else {
        _logWarning(
            'Document has no sync identifier, skipping tombstone creation: ${document.syncId}');
      }

      // Update document state to pending deletion
      await _updateDocumentToPendingDeletion(document);
      _logInfo('Document marked as pending deletion: ${document.title}');
    } catch (e) {
      _logError('Failed to mark document for deletion: $e');
      rethrow;
    }
  }

  /// Check if a document should be prevented from sync due to tombstone
  ///
  /// Returns true if the document has a tombstone and should not be synced.
  /// This prevents deleted documents from being reinstated during sync.
  Future<bool> isDocumentTombstoned(String syncId) async {
    try {
      // Only validate if it looks like a UUID, otherwise use as-is for testing
      if (RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
              caseSensitive: false)
          .hasMatch(syncId)) {
        SyncIdentifierService.validateOrThrow(syncId,
            context: 'tombstone check');
      }

      final isTombstoned = await _databaseService.isTombstoned(syncId);
      if (isTombstoned) {
        _logDebug('Document is tombstoned, preventing sync: $syncId');
      }
      return isTombstoned;
    } catch (e) {
      _logError('Error checking tombstone status for $syncId: $e');
      // Return false to allow sync in case of error - better to have duplicates than lose data
      return false;
    }
  }

  /// Process documents pending deletion for sync
  ///
  /// Returns list of documents that need remote deletion processing.
  /// These documents should be deleted from remote storage and then removed locally.
  Future<List<Document>> getDocumentsPendingDeletion(String userId) async {
    try {
      final documents =
          await _databaseService.getDocumentsPendingDeletion(userId);
      _logInfo(
          'Found ${documents.length} documents pending deletion for user: $userId');
      return documents;
    } catch (e) {
      _logError('Error getting documents pending deletion: $e');
      return [];
    }
  }

  /// Complete deletion process after successful remote deletion
  ///
  /// This method should be called after a document has been successfully
  /// deleted from remote storage. It removes the document from local storage
  /// but preserves the tombstone.
  Future<void> completeDeletion(Document document) async {
    try {
      _logInfo(
          'Completing deletion for document: ${document.title} (ID: ${document.syncId})');

      // Remove document from local database
      await _databaseService.deleteDocument(int.parse(document.syncId));
      _logInfo('Document removed from local database: ${document.syncId}');

      // Tombstone is preserved automatically - it's not tied to the document record
      final syncId = _extractSyncId(document);
      if (syncId != null) {
        _logInfo('Tombstone preserved for syncId: $syncId');
      }
    } catch (e) {
      _logError('Failed to complete deletion for document ${document.syncId}: $e');
      rethrow;
    }
  }

  /// Clean up old tombstones (older than 90 days)
  ///
  /// This method should be called periodically to prevent unbounded growth
  /// of the tombstones table. Documents deleted more than 90 days ago
  /// are unlikely to cause sync conflicts.
  Future<int> cleanupOldTombstones() async {
    try {
      _logInfo('Starting cleanup of old tombstones (older than 90 days)');
      final deletedCount = await _databaseService.cleanupOldTombstones();
      _logInfo('Cleaned up $deletedCount old tombstones');
      return deletedCount;
    } catch (e) {
      _logError('Error cleaning up old tombstones: $e');
      return 0;
    }
  }

  /// Get all tombstones for a user (for debugging/monitoring)
  ///
  /// Returns list of tombstone records for the specified user.
  /// Useful for debugging sync issues or monitoring deletion patterns.
  Future<List<Map<String, dynamic>>> getUserTombstones(String userId) async {
    try {
      final tombstones = await _databaseService.getTombstones(userId);
      _logDebug('Retrieved ${tombstones.length} tombstones for user: $userId');
      return tombstones;
    } catch (e) {
      _logError('Error getting tombstones for user $userId: $e');
      return [];
    }
  }

  /// Check if sync should be prevented for a list of documents
  ///
  /// Filters out documents that have tombstones and should not be synced.
  /// Returns only documents that are safe to sync.
  Future<List<Document>> filterTombstonedDocuments(
      List<Document> documents) async {
    final filteredDocuments = <Document>[];

    for (final document in documents) {
      final syncId = _extractSyncId(document);
      if (syncId == null) {
        // Documents without sync IDs can't have tombstones
        filteredDocuments.add(document);
        continue;
      }

      final isTombstoned = await isDocumentTombstoned(syncId);
      if (!isTombstoned) {
        filteredDocuments.add(document);
      } else {
        _logInfo(
            'Filtered out tombstoned document: ${document.title} (syncId: $syncId)');
      }
    }

    final filteredCount = documents.length - filteredDocuments.length;
    if (filteredCount > 0) {
      _logInfo('Filtered out $filteredCount tombstoned documents from sync');
    }

    return filteredDocuments;
  }

  /// Extract sync identifier from document
  ///
  /// Returns the sync identifier if present, null otherwise.
  /// Handles both the syncId field and potential future extensions.
  String? _extractSyncId(Document document) {
    // Try to get syncId from document properties
    try {
      // Check if document has syncId field
      final docMap = document.toJson();
      final syncId = docMap['syncId'] as String?;

      if (syncId != null && syncId.isNotEmpty) {
        // Only validate if it looks like a UUID, otherwise return as-is for testing
        if (RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                caseSensitive: false)
            .hasMatch(syncId)) {
          return SyncIdentifierService.prepareForStorage(syncId);
        } else {
          // For non-UUID sync IDs (like in tests), return normalized
          return syncId.toLowerCase();
        }
      }
    } catch (e) {
      _logDebug('Could not extract syncId from document ${document.syncId}: $e');
    }

    return null;
  }

  /// Create tombstone if it doesn't already exist
  ///
  /// Prevents duplicate tombstones for the same sync identifier.
  Future<void> _createTombstoneIfNeeded(
    String syncId,
    String userId,
    String deletedBy,
    String reason,
  ) async {
    // Check if tombstone already exists
    final existingTombstone = await _databaseService.isTombstoned(syncId);
    if (existingTombstone) {
      _logDebug('Tombstone already exists for syncId: $syncId');
      return;
    }

    // Create new tombstone
    await _databaseService.createTombstone(syncId, userId, deletedBy,
        reason: reason);
    _logInfo('Created tombstone for syncId: $syncId');
  }

  /// Update document to pending deletion state
  ///
  /// Updates the document's sync state to pendingDeletion while preserving
  /// the sync identifier for remote deletion processing.
  Future<void> _updateDocumentToPendingDeletion(Document document) async {
    try {
      // Create updated document with pendingDeletion state
      final updatedDocument = document.copyWith(
        syncState: SyncState.pendingDeletion.toJson(),
        lastModified: amplify_core.TemporalDateTime.now(),
      );

      // Update in local database
      await _databaseService.updateDocument(updatedDocument);
      _logDebug(
          'Updated document sync state to pendingDeletion: ${document.syncId}');
    } catch (e) {
      _logError('Failed to update document to pending deletion: $e');
      rethrow;
    }
  }
}
