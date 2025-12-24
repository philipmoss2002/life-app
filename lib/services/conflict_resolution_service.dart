import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Document.dart';
import '../models/Conflict.dart' as conflict_model;
import '../models/sync_state.dart';
import 'database_service.dart';
import 'analytics_service.dart';
import 'authentication_service.dart';
import '../utils/sync_identifier_generator.dart';

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
  final String? syncId; // Add sync identifier for tracking
  final Document localDocument;
  final Document remoteDocument;
  final ConflictType type;
  final DateTime detectedAt;
  final bool isResolved;
  final String? resolutionStrategy;

  DocumentConflict({
    required this.id,
    required this.documentId,
    this.syncId,
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
    String? syncId,
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
      syncId: syncId ?? this.syncId,
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
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthenticationService _authService = AuthenticationService();
  final Map<String, DocumentConflict> _activeConflicts = {};
  final StreamController<DocumentConflict> _conflictController =
      StreamController<DocumentConflict>.broadcast();
  final StreamController<conflict_model.Conflict> _conflictStreamController =
      StreamController<conflict_model.Conflict>.broadcast();

  /// Get current user ID for conflict tracking
  Future<String> _getCurrentUserId() async {
    final user = await _authService.getCurrentUser();
    return user?.id ?? 'unknown';
  }

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
    // Use sync identifier if available, otherwise fall back to document ID
    final syncId = localDocument.syncId;
    final conflictId = '${syncId}_${DateTime.now().millisecondsSinceEpoch}';

    final conflict = DocumentConflict(
      id: conflictId,
      documentId: documentId,
      syncId: syncId,
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
        'Conflict registered for document $documentId (syncId: $syncId): ${conflictType.name}');
  }

  /// Get all active conflicts
  List<DocumentConflict> getActiveConflicts() {
    return _activeConflicts.values.where((c) => !c.isResolved).toList();
  }

  /// Detect conflict between two document versions
  /// Uses sync identifier as primary matching criterion
  Future<conflict_model.Conflict?> detectConflict(
      Document localDoc, Document remoteDoc) async {
    // Validate that documents have matching sync identifiers if both are present
    if (localDoc.syncId != remoteDoc.syncId) {
      safePrint('Warning: Comparing documents with different sync identifiers: '
          'local=${localDoc.syncId}, remote=${remoteDoc.syncId}');
      // These are different documents, not a conflict
      return null;
    }

    // No conflict if documents are identical
    if (localDoc.syncId == remoteDoc.syncId &&
        localDoc.version == remoteDoc.version &&
        localDoc.title == remoteDoc.title &&
        localDoc.lastModified == remoteDoc.lastModified) {
      return null;
    }

    // Detect conflict if same version but different content or modification times
    if (localDoc.version == remoteDoc.version) {
      if (localDoc.title != remoteDoc.title ||
          localDoc.lastModified != remoteDoc.lastModified) {
        final syncId = localDoc.syncId;
        final userId = await _getCurrentUserId();
        final conflict = conflict_model.Conflict(
          userId: userId,
          entityType: 'document',
          entityId: localDoc.syncId,
          localVersion: localDoc.toJson().toString(),
          remoteVersion: remoteDoc.toJson().toString(),
          detectedAt: amplify_core.TemporalDateTime.now(),
        );

        // Emit to stream
        _conflictStreamController.add(conflict);

        // Also add to active conflicts for tracking
        final documentConflict = DocumentConflict(
          id: conflict.id,
          documentId: conflict.entityId,
          syncId: syncId,
          localDocument: localDoc,
          remoteDocument: remoteDoc,
          type: ConflictType.versionMismatch,
          detectedAt: DateTime.now(),
        );
        _activeConflicts[conflict.id] = documentConflict;

        // Track conflict detection in analytics
        _analyticsService.trackConflictDetected(
          documentId: conflict.entityId,
          syncId: syncId,
          conflictType: 'version_mismatch',
        );

        return conflict;
      }
    }

    // Detect conflict if remote was modified after local but has older/same version
    final localTime = localDoc.lastModified.getDateTimeInUtc();
    final remoteTime = remoteDoc.lastModified.getDateTimeInUtc();

    if (remoteTime.isAfter(localTime) &&
        remoteDoc.version <= localDoc.version) {
      final syncId = localDoc.syncId;
      final userId = await _getCurrentUserId();
      final conflict = conflict_model.Conflict(
        userId: userId,
        entityType: 'document',
        entityId: localDoc.syncId,
        localVersion: localDoc.toJson().toString(),
        remoteVersion: remoteDoc.toJson().toString(),
        detectedAt: amplify_core.TemporalDateTime.now(),
      );

      // Emit to stream
      _conflictStreamController.add(conflict);

      // Also add to active conflicts for tracking
      final documentConflict = DocumentConflict(
        id: conflict.id,
        documentId: conflict.entityId,
        syncId: syncId,
        localDocument: localDoc,
        remoteDocument: remoteDoc,
        type: ConflictType.concurrentModification,
        detectedAt: DateTime.now(),
      );
      _activeConflicts[conflict.id] = documentConflict;

      // Track conflict detection in analytics
      _analyticsService.trackConflictDetected(
        documentId: conflict.entityId,
        syncId: syncId,
        conflictType: 'concurrent_modification',
      );

      return conflict;
    }

    return null;
  }

  /// Merge two document versions
  /// Preserves the original document's sync identifier
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

  /// Create a conflict copy with a new sync identifier
  /// Used when user wants to keep both versions of a conflicted document
  Future<Document> createConflictCopy(Document document) async {
    // Generate a new sync identifier for the conflict copy
    final newSyncId = SyncIdentifierGenerator.generate();

    // Create a copy with the new sync identifier and modified title
    final conflictCopy = document.copyWith(
      title: '${document.title} (Conflict Copy)',
      version: 1, // Reset version for new document
      createdAt: amplify_core.TemporalDateTime.now(),
      lastModified: amplify_core.TemporalDateTime.now(),
      syncState: SyncState.pending.toJson(),
      conflictId: null,
    );

    // Save the conflict copy to the database
    await _databaseService.createDocument(conflictCopy);

    safePrint(
        'Created conflict copy with new syncId: $newSyncId for original syncId: ${document.syncId}');

    return conflictCopy;
  }

  /// Resolve conflict using the new Conflict model
  /// Preserves sync identifier in resolved document
  Future<Document> resolveConflictNew(
      conflict_model.Conflict conflict, ConflictResolution resolution) async {
    // Remove from active conflicts first
    _activeConflicts
        .removeWhere((key, value) => value.documentId == conflict.entityId);

    // Parse the document versions from JSON strings
    final localDoc = Document.fromJson(
        Map<String, dynamic>.from(jsonDecode(conflict.localVersion)));
    final remoteDoc = Document.fromJson(
        Map<String, dynamic>.from(jsonDecode(conflict.remoteVersion)));

    Document resolvedDoc;

    switch (resolution) {
      case ConflictResolution.keepLocal:
        resolvedDoc = localDoc.copyWith(
          syncState: SyncState.pending.toJson(),
          conflictId: null,
        );
        break;
      case ConflictResolution.keepRemote:
        // Preserve the local document's sync identifier when keeping remote
        resolvedDoc = remoteDoc.copyWith(
          syncState: SyncState.synced.toJson(),
          conflictId: null,
        );
        break;
      case ConflictResolution.merge:
        resolvedDoc = await mergeDocuments(localDoc, remoteDoc);
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

  /// Get conflicts for a specific sync identifier
  List<DocumentConflict> getConflictsForSyncId(String syncId) {
    return _activeConflicts.values
        .where((c) => c.syncId == syncId && !c.isResolved)
        .toList();
  }

  /// Get conflict by sync identifier (returns the first match)
  DocumentConflict? getConflictBySyncId(String syncId) {
    return _activeConflicts.values
        .where((c) => c.syncId == syncId && !c.isResolved)
        .firstOrNull;
  }

  /// Resolve a conflict using the specified strategy
  /// Preserves sync identifier in resolved document
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
        resolvedDocument = await _resolveMerge(conflict);
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

    // Track conflict resolution in analytics
    _analyticsService.trackConflictResolved(
      conflictId: conflictId,
      resolutionStrategy: strategy.name,
    );

    // Update document with resolved version
    final finalDocument = resolvedDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null,
      version: resolvedDocument.version + 1,
      lastModified: amplify_core.TemporalDateTime.now(),
    );

    await _databaseService.updateDocument(finalDocument);

    final syncIdInfo =
        conflict.syncId != null ? ' (syncId: ${conflict.syncId})' : '';
    safePrint(
        'Conflict resolved for document ${conflict.documentId}$syncIdInfo using ${strategy.name}');
    return finalDocument;
  }

  /// Resolve conflict manually with a provided document
  /// Preserves sync identifier in resolved document
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

    // Ensure the resolved document preserves the original sync identifier
    final documentWithSyncId = resolvedDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null,
      version: resolvedDocument.version + 1,
      lastModified: amplify_core.TemporalDateTime.now(),
    );

    // Mark conflict as resolved
    final resolvedConflict = conflict.copyWith(
      isResolved: true,
      resolutionStrategy: ConflictResolutionStrategy.manual.name,
    );
    _activeConflicts[conflictId] = resolvedConflict;

    // Update document with resolved version
    final finalDocument = documentWithSyncId.copyWith(
      version: documentWithSyncId.version + 1,
      lastModified: amplify_core.TemporalDateTime.now(),
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
    // Preserve the local document's sync identifier when keeping remote
    return conflict.remoteDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null,
    );
  }

  Future<Document> _resolveMerge(DocumentConflict conflict) async {
    return await mergeDocuments(
        conflict.localDocument, conflict.remoteDocument);
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
