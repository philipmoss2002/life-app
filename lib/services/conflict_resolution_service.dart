import 'dart:async';
import 'dart:math' as math;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Document.dart';
import '../models/conflict.dart' as conflict_model;
import '../models/sync_state.dart';
import 'database_service.dart';

/// Types of conflicts that can occur during synchronization
enum ConflictType {
  versionMismatch,
  concurrentModification,
  deletionConflict,
}

/// Resolution strategies for conflicts
enum ConflictResolution {
  keepLocal,
  keepRemote,
  merge,
}

/// Represents a conflict between local and remote document versions
class DocumentConflict {
  final String id;
  final String documentId;
  final Document localDocument;
  final Document remoteDocument;
  final ConflictType type;
  final DateTime detectedAt;
  final bool isResolved;
  final String? resolutionStrategy;

  DocumentConflict({
    required this.id,
    required this.documentId,
    required this.localDocument,
    required this.remoteDocument,
    required this.type,
    required this.detectedAt,
    this.isResolved = false,
    this.resolutionStrategy,
  });

  DocumentConflict copyWith({
    String? id,
    String? documentId,
    Document? localDocument,
    Document? remoteDocument,
    ConflictType? type,
    DateTime? detectedAt,
    bool? isResolved,
    String? resolutionStrategy,
  }) {
    return DocumentConflict(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      localDocument: localDocument ?? this.localDocument,
      remoteDocument: remoteDocument ?? this.remoteDocument,
      type: type ?? this.type,
      detectedAt: detectedAt ?? this.detectedAt,
      isResolved: isResolved ?? this.isResolved,
      resolutionStrategy: resolutionStrategy ?? this.resolutionStrategy,
    );
  }
}

/// Resolution strategies for conflicts
enum ConflictResolutionStrategy {
  keepLocal,
  keepRemote,
  merge,
  manual,
}

/// Service for handling document synchronization conflicts
class ConflictResolutionService {
  static final ConflictResolutionService _instance =
      ConflictResolutionService._internal();
  factory ConflictResolutionService() => _instance;
  ConflictResolutionService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final Map<String, DocumentConflict> _activeConflicts = {};
  final StreamController<DocumentConflict> _conflictController =
      StreamController<DocumentConflict>.broadcast();
  final StreamController<conflict_model.Conflict> _conflictStreamController =
      StreamController<conflict_model.Conflict>.broadcast();

  /// Stream of detected conflicts
  Stream<DocumentConflict> get conflicts => _conflictController.stream;

  /// Stream of detected conflicts (new interface)
  Stream<conflict_model.Conflict> get conflictStream =>
      _conflictStreamController.stream;

  /// Register a new conflict
  Future<void> registerConflict({
    required String documentId,
    required Document localDocument,
    required Document remoteDocument,
    required ConflictType conflictType,
  }) async {
    final conflictId = '${documentId}_${DateTime.now().millisecondsSinceEpoch}';

    final conflict = DocumentConflict(
      id: conflictId,
      documentId: documentId,
      localDocument: localDocument,
      remoteDocument: remoteDocument,
      type: conflictType,
      detectedAt: DateTime.now(),
    );

    _activeConflicts[conflictId] = conflict;

    // Update document to conflict state
    final conflictDocument = localDocument.copyWith(
      syncState: SyncState.conflict.toJson(),
      conflictId: conflictId,
    );

    await _databaseService.updateDocument(conflictDocument);

    // Emit conflict event
    _conflictController.add(conflict);

    safePrint(
        'Conflict registered for document $documentId: ${conflictType.name}');
  }

  /// Get all active conflicts
  List<DocumentConflict> getActiveConflicts() {
    return _activeConflicts.values.where((c) => !c.isResolved).toList();
  }

  /// Detect conflict between two document versions
  conflict_model.Conflict? detectConflict(
      Document localDoc, Document remoteDoc) {
    // No conflict if documents are identical
    if (localDoc.id == remoteDoc.id &&
        localDoc.version == remoteDoc.version &&
        localDoc.title == remoteDoc.title &&
        localDoc.lastModified == remoteDoc.lastModified) {
      return null;
    }

    // Detect conflict if same version but different content or modification times
    if (localDoc.version == remoteDoc.version) {
      if (localDoc.title != remoteDoc.title ||
          localDoc.lastModified != remoteDoc.lastModified) {
        final conflict = conflict_model.Conflict(
          id: '${localDoc.id}_${DateTime.now().millisecondsSinceEpoch}',
          documentId: localDoc.id,
          localVersion: localDoc,
          remoteVersion: remoteDoc,
          type: conflict_model.ConflictType.documentModified,
        );

        // Emit to stream
        _conflictStreamController.add(conflict);

        // Also add to active conflicts for tracking
        final documentConflict = DocumentConflict(
          id: conflict.id,
          documentId: conflict.documentId,
          localDocument: conflict.localVersion,
          remoteDocument: conflict.remoteVersion,
          type: ConflictType.versionMismatch,
          detectedAt: conflict.detectedAt,
        );
        _activeConflicts[conflict.id] = documentConflict;

        return conflict;
      }
    }

    // Detect conflict if remote was modified after local but has older/same version
    final localTime = localDoc.lastModified.getDateTimeInUtc();
    final remoteTime = remoteDoc.lastModified.getDateTimeInUtc();

    if (remoteTime.isAfter(localTime) &&
        remoteDoc.version <= localDoc.version) {
      final conflict = conflict_model.Conflict(
        id: '${localDoc.id}_${DateTime.now().millisecondsSinceEpoch}',
        documentId: localDoc.id,
        localVersion: localDoc,
        remoteVersion: remoteDoc,
        type: conflict_model.ConflictType.documentModified,
      );

      // Emit to stream
      _conflictStreamController.add(conflict);

      // Also add to active conflicts for tracking
      final documentConflict = DocumentConflict(
        id: conflict.id,
        documentId: conflict.documentId,
        localDocument: conflict.localVersion,
        remoteDocument: conflict.remoteVersion,
        type: ConflictType.concurrentModification,
        detectedAt: conflict.detectedAt,
      );
      _activeConflicts[conflict.id] = documentConflict;

      return conflict;
    }

    return null;
  }

  /// Merge two document versions
  Future<Document> mergeDocuments(Document localDoc, Document remoteDoc) async {
    // Use the more recent title
    final useLocalTitle = localDoc.lastModified
        .getDateTimeInUtc()
        .isAfter(remoteDoc.lastModified.getDateTimeInUtc());

    // Merge file paths (combine unique paths)
    final mergedFilePaths = <String>{};
    mergedFilePaths.addAll(localDoc.filePaths);
    mergedFilePaths.addAll(remoteDoc.filePaths);

    // Merge notes
    String? mergedNotes;
    if (localDoc.notes != null && remoteDoc.notes != null) {
      if (localDoc.notes == remoteDoc.notes) {
        mergedNotes = localDoc.notes;
      } else {
        mergedNotes =
            '${localDoc.notes}\n\n--- Merged from other device ---\n\n${remoteDoc.notes}';
      }
    } else {
      mergedNotes = localDoc.notes ?? remoteDoc.notes;
    }

    // Use earlier creation date
    final useLocalCreatedAt = localDoc.createdAt
        .getDateTimeInUtc()
        .isBefore(remoteDoc.createdAt.getDateTimeInUtc());

    // Use renewal date from either version (prefer non-null)
    final renewalDate = localDoc.renewalDate ?? remoteDoc.renewalDate;

    return localDoc.copyWith(
      title: useLocalTitle ? localDoc.title : remoteDoc.title,
      filePaths: mergedFilePaths.toList(),
      notes: mergedNotes,
      createdAt: useLocalCreatedAt ? localDoc.createdAt : remoteDoc.createdAt,
      renewalDate: renewalDate,
      version: math.max(localDoc.version, remoteDoc.version) + 1,
      lastModified: amplify_core.TemporalDateTime.now(),
      syncState: SyncState.pending.toJson(),
    );
  }

  /// Resolve conflict using the new Conflict model
  Future<Document> resolveConflictNew(
      conflict_model.Conflict conflict, ConflictResolution resolution) async {
    // Remove from active conflicts first
    _activeConflicts
        .removeWhere((key, value) => value.documentId == conflict.documentId);

    Document resolvedDoc;

    switch (resolution) {
      case ConflictResolution.keepLocal:
        resolvedDoc = conflict.localVersion.copyWith(
          syncState: SyncState.pending.toJson(),
          conflictId: null,
        );
        break;
      case ConflictResolution.keepRemote:
        resolvedDoc = conflict.remoteVersion.copyWith(
          syncState: SyncState.synced.toJson(),
          conflictId: null,
        );
        break;
      case ConflictResolution.merge:
        resolvedDoc =
            await mergeDocuments(conflict.localVersion, conflict.remoteVersion);
        break;
    }

    // Update in database
    await _databaseService.updateDocument(resolvedDoc);

    return resolvedDoc;
  }

  /// Get conflict by ID
  DocumentConflict? getConflict(String conflictId) {
    return _activeConflicts[conflictId];
  }

  /// Get conflicts for a specific document
  List<DocumentConflict> getConflictsForDocument(String documentId) {
    return _activeConflicts.values
        .where((c) => c.documentId == documentId && !c.isResolved)
        .toList();
  }

  /// Resolve a conflict using the specified strategy
  Future<Document> resolveConflict(
    String conflictId,
    ConflictResolutionStrategy strategy,
  ) async {
    final conflict = _activeConflicts[conflictId];
    if (conflict == null) {
      throw Exception('Conflict not found: $conflictId');
    }

    if (conflict.isResolved) {
      throw Exception('Conflict already resolved: $conflictId');
    }

    Document resolvedDocument;

    switch (strategy) {
      case ConflictResolutionStrategy.keepLocal:
        resolvedDocument = _resolveKeepLocal(conflict);
        break;
      case ConflictResolutionStrategy.keepRemote:
        resolvedDocument = _resolveKeepRemote(conflict);
        break;
      case ConflictResolutionStrategy.merge:
        resolvedDocument = _resolveMerge(conflict);
        break;
      case ConflictResolutionStrategy.manual:
        throw Exception('Manual resolution requires explicit document');
    }

    // Mark conflict as resolved
    final resolvedConflict = conflict.copyWith(
      isResolved: true,
      resolutionStrategy: strategy.name,
    );
    _activeConflicts[conflictId] = resolvedConflict;

    // Update document with resolved version
    final finalDocument = resolvedDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null,
      version: resolvedDocument.version + 1,
      lastModified: TemporalDateTime.now(),
    );

    await _databaseService.updateDocument(finalDocument);

    safePrint(
        'Conflict resolved for document ${conflict.documentId} using ${strategy.name}');
    return finalDocument;
  }

  /// Resolve conflict manually with a provided document
  Future<Document> resolveConflictManually(
    String conflictId,
    Document resolvedDocument,
  ) async {
    final conflict = _activeConflicts[conflictId];
    if (conflict == null) {
      throw Exception('Conflict not found: $conflictId');
    }

    if (conflict.isResolved) {
      throw Exception('Conflict already resolved: $conflictId');
    }

    // Mark conflict as resolved
    final resolvedConflict = conflict.copyWith(
      isResolved: true,
      resolutionStrategy: ConflictResolutionStrategy.manual.name,
    );
    _activeConflicts[conflictId] = resolvedConflict;

    // Update document with resolved version
    final finalDocument = resolvedDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null,
      version: resolvedDocument.version + 1,
      lastModified: TemporalDateTime.now(),
    );

    await _databaseService.updateDocument(finalDocument);

    safePrint('Conflict resolved manually for document ${conflict.documentId}');
    return finalDocument;
  }

  /// Auto-resolve conflicts based on predefined rules
  Future<void> autoResolveConflicts() async {
    final conflicts = getActiveConflicts();

    for (final conflict in conflicts) {
      try {
        // Auto-resolution rules:
        // 1. If remote is newer by more than 1 hour, keep remote
        // 2. If local has more recent modifications, keep local
        // 3. Otherwise, attempt merge

        final timeDiff = conflict.remoteDocument.lastModified
            .getDateTimeInUtc()
            .difference(conflict.localDocument.lastModified.getDateTimeInUtc());

        ConflictResolutionStrategy strategy;

        if (timeDiff.inHours > 1) {
          strategy = ConflictResolutionStrategy.keepRemote;
        } else if (timeDiff.inHours < -1) {
          strategy = ConflictResolutionStrategy.keepLocal;
        } else {
          strategy = ConflictResolutionStrategy.merge;
        }

        await resolveConflict(conflict.id, strategy);
        safePrint(
            'Auto-resolved conflict ${conflict.id} using ${strategy.name}');
      } catch (e) {
        safePrint('Failed to auto-resolve conflict ${conflict.id}: $e');
      }
    }
  }

  /// Clear resolved conflicts older than specified duration
  Future<void> clearResolvedConflicts({Duration? olderThan}) async {
    final cutoffTime =
        DateTime.now().subtract(olderThan ?? const Duration(days: 7));

    final toRemove = _activeConflicts.entries
        .where((entry) =>
            entry.value.isResolved &&
            entry.value.detectedAt.isBefore(cutoffTime))
        .map((entry) => entry.key)
        .toList();

    for (final conflictId in toRemove) {
      _activeConflicts.remove(conflictId);
    }

    safePrint('Cleared ${toRemove.length} resolved conflicts');
  }

  // Private resolution methods

  Document _resolveKeepLocal(DocumentConflict conflict) {
    return conflict.localDocument;
  }

  Document _resolveKeepRemote(DocumentConflict conflict) {
    return conflict.remoteDocument;
  }

  Document _resolveMerge(DocumentConflict conflict) {
    final local = conflict.localDocument;
    final remote = conflict.remoteDocument;

    // Simple merge strategy - prefer non-empty values and most recent timestamps
    return local.copyWith(
      title: _mergeStringField(
          local.title, remote.title, local.lastModified, remote.lastModified),
      category: _mergeStringField(local.category, remote.category,
          local.lastModified, remote.lastModified),
      notes: _mergeStringField(local.notes ?? '', remote.notes ?? '',
          local.lastModified, remote.lastModified),
      renewalDate: _mergeDateField(local.renewalDate, remote.renewalDate,
          local.lastModified, remote.lastModified),
      filePaths: _mergeFilePaths(local.filePaths, remote.filePaths),
      version: math.max(local.version, remote.version),
      lastModified: local.lastModified
              .getDateTimeInUtc()
              .isAfter(remote.lastModified.getDateTimeInUtc())
          ? local.lastModified
          : remote.lastModified,
    );
  }

  String _mergeStringField(String local, String remote,
      TemporalDateTime localTime, TemporalDateTime remoteTime) {
    if (local.isEmpty && remote.isNotEmpty) return remote;
    if (remote.isEmpty && local.isNotEmpty) return local;

    // If both have values, prefer the one with more recent modification
    return localTime.getDateTimeInUtc().isAfter(remoteTime.getDateTimeInUtc())
        ? local
        : remote;
  }

  TemporalDateTime? _mergeDateField(
      TemporalDateTime? local,
      TemporalDateTime? remote,
      TemporalDateTime localTime,
      TemporalDateTime remoteTime) {
    if (local == null && remote != null) return remote;
    if (remote == null && local != null) return local;
    if (local == null && remote == null) return null;

    // If both have values, prefer the one with more recent modification
    return localTime.getDateTimeInUtc().isAfter(remoteTime.getDateTimeInUtc())
        ? local
        : remote;
  }

  List<String> _mergeFilePaths(List<String> local, List<String> remote) {
    // Merge file paths by combining unique paths
    final merged = <String>{};
    merged.addAll(local);
    merged.addAll(remote);
    return merged.toList();
  }

  /// Clear all active conflicts (for testing)
  void clearActiveConflicts() {
    _activeConflicts.clear();
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _conflictController.close();
    await _conflictStreamController.close();
    _activeConflicts.clear();
  }
}
