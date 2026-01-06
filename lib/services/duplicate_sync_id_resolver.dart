import '../models/Document.dart';
import 'sync_identifier_service.dart';
import 'log_service.dart';

/// Service to handle duplicate sync identifier resolution
class DuplicateSyncIdResolver {
  static final DuplicateSyncIdResolver _instance =
      DuplicateSyncIdResolver._internal();
  factory DuplicateSyncIdResolver() => _instance;
  DuplicateSyncIdResolver._internal();

  final LogService _logService = LogService();
  final Set<String> _usedSyncIds = <String>{};

  /// Check if a sync ID is already in use and resolve duplicates
  String resolveDuplicateSyncId(String originalSyncId, {String? context}) {
    // If this sync ID hasn't been used, mark it as used and return it
    if (!_usedSyncIds.contains(originalSyncId)) {
      _usedSyncIds.add(originalSyncId);
      return originalSyncId;
    }

    // Generate a new unique sync ID
    String newSyncId;
    int attempts = 0;
    const maxAttempts = 10;

    do {
      newSyncId = SyncIdentifierService.generateValidated();
      attempts++;

      if (attempts >= maxAttempts) {
        throw Exception(
            'Failed to generate unique sync ID after $maxAttempts attempts');
      }
    } while (_usedSyncIds.contains(newSyncId));

    _usedSyncIds.add(newSyncId);

    _logService.log(
      'Resolved duplicate sync ID: $originalSyncId -> $newSyncId${context != null ? ' (context: $context)' : ''}',
      level: LogLevel.warning,
    );

    return newSyncId;
  }

  /// Mark a sync ID as used (for existing documents)
  void markSyncIdAsUsed(String syncId) {
    _usedSyncIds.add(syncId);
  }

  /// Clear all tracked sync IDs (for testing or reset)
  void clearTrackedSyncIds() {
    _usedSyncIds.clear();
  }

  /// Get count of tracked sync IDs
  int getTrackedSyncIdCount() {
    return _usedSyncIds.length;
  }

  /// Check if a sync ID is being tracked
  bool isSyncIdTracked(String syncId) {
    return _usedSyncIds.contains(syncId);
  }

  /// Initialize with existing sync IDs from documents
  void initializeWithExistingDocuments(List<Document> documents) {
    _usedSyncIds.clear();

    for (final document in documents) {
      if (document.syncId.isNotEmpty) {
        _usedSyncIds.add(document.syncId);
      }
    }

    _logService.log(
      'Initialized duplicate sync ID resolver with ${_usedSyncIds.length} existing sync IDs',
      level: LogLevel.info,
    );
  }

  /// Resolve duplicate sync ID for a document
  Document resolveDuplicateForDocument(Document document, {String? context}) {
    if (document.syncId.isEmpty) {
      // Generate new sync ID for document without one
      final newSyncId = SyncIdentifierService.generateValidated();
      _usedSyncIds.add(newSyncId);

      _logService.log(
        'Generated sync ID for document without one: $newSyncId${context != null ? ' (context: $context)' : ''}',
        level: LogLevel.info,
      );

      return Document(
        syncId: newSyncId,
        userId: document.userId,
        title: document.title,
        category: document.category,
        filePaths: document.filePaths,
        renewalDate: document.renewalDate,
        notes: document.notes,
        createdAt: document.createdAt,
        lastModified: document.lastModified,
        version: document.version,
        syncState: document.syncState,
        conflictId: document.conflictId,
        deleted: document.deleted,
        deletedAt: document.deletedAt,
        contentHash: document.contentHash,
        fileAttachments: document.fileAttachments,
      );
    }

    final resolvedSyncId =
        resolveDuplicateSyncId(document.syncId, context: context);

    if (resolvedSyncId != document.syncId) {
      return Document(
        syncId: resolvedSyncId,
        userId: document.userId,
        title: document.title,
        category: document.category,
        filePaths: document.filePaths,
        renewalDate: document.renewalDate,
        notes: document.notes,
        createdAt: document.createdAt,
        lastModified: document.lastModified,
        version: document.version,
        syncState: document.syncState,
        conflictId: document.conflictId,
        deleted: document.deleted,
        deletedAt: document.deletedAt,
        contentHash: document.contentHash,
        fileAttachments: document.fileAttachments,
      );
    }

    return document;
  }

  /// Check for and resolve duplicate sync IDs in a list of documents
  List<Document> resolveAllDuplicates(List<Document> documents,
      {String? context}) {
    final resolvedDocuments = <Document>[];
    _usedSyncIds.clear();

    for (final document in documents) {
      final resolvedDocument =
          resolveDuplicateForDocument(document, context: context);
      resolvedDocuments.add(resolvedDocument);
    }

    return resolvedDocuments;
  }
}
