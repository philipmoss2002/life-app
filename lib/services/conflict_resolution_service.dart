import 'dart:async';
import '../models/conflict.dart';
import '../models/document.dart';
import '../models/file_attachment.dart';
import '../models/sync_state.dart';
import 'database_service.dart';

/// Resolution strategy for conflicts
enum ConflictResolution {
  /// Keep the local version
  keepLocal,

  /// Keep the remote version
  keepRemote,

  /// Merge both versions
  merge,
}

/// Service for detecting and resolving synchronization conflicts
class ConflictResolutionService {
  final DatabaseService _databaseService;
  final Map<String, Conflict> _activeConflicts = {};
  final StreamController<Conflict> _conflictController =
      StreamController<Conflict>.broadcast();

  ConflictResolutionService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  /// Stream of detected conflicts
  Stream<Conflict> get conflictStream => _conflictController.stream;

  /// Detect if there's a conflict between local and remote versions
  /// Returns a Conflict object if conflict detected, null otherwise
  Conflict? detectConflict(Document local, Document remote) {
    // No conflict if versions and content are identical
    if (local.version == remote.version &&
        local.lastModified == remote.lastModified) {
      return null;
    }

    // Detect conflict when both versions have diverged
    // This happens when:
    // 1. Same version number but different modification times (concurrent edits)
    // 2. Different version numbers with overlapping modification times

    bool hasConflict = false;

    // Case 1: Same version but different modifications (concurrent edits)
    if (local.version == remote.version &&
        local.lastModified != remote.lastModified) {
      hasConflict = true;
    }

    // Case 2: Local is ahead in version but remote was modified more recently
    // This indicates remote changes that weren't synced before local changes
    if (local.version > remote.version &&
        remote.lastModified.isAfter(local.lastModified)) {
      hasConflict = true;
    }

    // Case 3: Remote is ahead in version but local was modified more recently
    // This indicates local changes that weren't synced before remote changes
    if (remote.version > local.version &&
        local.lastModified.isAfter(remote.lastModified)) {
      hasConflict = true;
    }

    if (hasConflict) {
      final conflict = Conflict(
        id: '${local.id}_${DateTime.now().millisecondsSinceEpoch}',
        documentId: local.id?.toString() ?? '',
        localVersion: local,
        remoteVersion: remote,
        type: ConflictType.documentModified,
      );
      _activeConflicts[conflict.id] = conflict;
      _conflictController.add(conflict);
      return conflict;
    }

    return null;
  }

  /// Get all active conflicts
  Future<List<Conflict>> getActiveConflicts() async {
    return _activeConflicts.values.toList();
  }

  /// Resolve a conflict with the specified resolution strategy
  Future<Document> resolveConflict(
    Conflict conflict,
    ConflictResolution resolution,
  ) async {
    Document resolvedDocument;

    switch (resolution) {
      case ConflictResolution.keepLocal:
        resolvedDocument = conflict.localVersion.copyWith(
          syncState: SyncState.pending,
          conflictId: null,
        );
        break;

      case ConflictResolution.keepRemote:
        resolvedDocument = conflict.remoteVersion.copyWith(
          syncState: SyncState.synced,
          conflictId: null,
        );
        break;

      case ConflictResolution.merge:
        resolvedDocument = await mergeDocuments(
          conflict.localVersion,
          conflict.remoteVersion,
        );
        break;
    }

    // Remove from active conflicts first
    _activeConflicts.remove(conflict.id);

    // Update the document in the database
    await _databaseService.updateDocument(resolvedDocument);

    return resolvedDocument;
  }

  /// Automatically merge non-conflicting fields from both versions
  Future<Document> mergeDocuments(Document local, Document remote) async {
    // Use the higher version number and increment
    final mergedVersion =
        (local.version > remote.version ? local.version : remote.version) + 1;

    // For text fields, prefer the most recently modified version
    final useLocal = local.lastModified.isAfter(remote.lastModified);

    // Merge file paths - combine both lists and remove duplicates
    final mergedFilePaths = <String>{
      ...local.filePaths,
      ...remote.filePaths,
    }.toList();

    // Merge file attachments - combine both lists
    final mergedAttachments = <FileAttachment>{
      ...local.fileAttachments,
      ...remote.fileAttachments,
    }.toList();

    return Document(
      id: local.id,
      userId: local.userId ?? remote.userId,
      title: useLocal ? local.title : remote.title,
      category: useLocal ? local.category : remote.category,
      filePaths: mergedFilePaths,
      fileAttachments: mergedAttachments,
      renewalDate: local.renewalDate ?? remote.renewalDate,
      notes: _mergeNotes(local.notes, remote.notes),
      createdAt: local.createdAt.isBefore(remote.createdAt)
          ? local.createdAt
          : remote.createdAt,
      lastModified: DateTime.now(),
      version: mergedVersion,
      syncState: SyncState.pending,
      conflictId: null,
    );
  }

  /// Merge notes from both versions
  String? _mergeNotes(String? localNotes, String? remoteNotes) {
    if (localNotes == null) return remoteNotes;
    if (remoteNotes == null) return localNotes;
    if (localNotes == remoteNotes) return localNotes;

    // If both have notes and they're different, combine them
    return '$localNotes\n\n--- Merged from other device ---\n\n$remoteNotes';
  }

  /// Dispose resources
  void dispose() {
    _conflictController.close();
  }
}
