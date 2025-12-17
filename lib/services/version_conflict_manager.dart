import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';

/// Strategies for resolving version conflicts
enum ConflictResolutionStrategy {
  /// Keep the local version and discard remote changes
  keepLocal,

  /// Keep the remote version and discard local changes
  keepRemote,

  /// Merge both versions (requires manual intervention)
  merge,

  /// Create a new version with both changes preserved
  createBranch,
}

/// Information about a version conflict
class VersionConflict {
  final String documentId;
  final Document localDocument;
  final Document remoteDocument;
  final DateTime detectedAt;
  final String conflictId;

  VersionConflict({
    required this.documentId,
    required this.localDocument,
    required this.remoteDocument,
    required this.detectedAt,
    required this.conflictId,
  });

  /// Get a summary of the differences between versions
  Map<String, dynamic> getDifferences() {
    final differences = <String, dynamic>{};

    if (localDocument.title != remoteDocument.title) {
      differences['title'] = {
        'local': localDocument.title,
        'remote': remoteDocument.title,
      };
    }

    if (localDocument.category != remoteDocument.category) {
      differences['category'] = {
        'local': localDocument.category,
        'remote': remoteDocument.category,
      };
    }

    if (localDocument.notes != remoteDocument.notes) {
      differences['notes'] = {
        'local': localDocument.notes,
        'remote': remoteDocument.notes,
      };
    }

    if (localDocument.renewalDate != remoteDocument.renewalDate) {
      differences['renewalDate'] = {
        'local': localDocument.renewalDate?.format(),
        'remote': remoteDocument.renewalDate?.format(),
      };
    }

    if (!_listEquals(localDocument.filePaths, remoteDocument.filePaths)) {
      differences['filePaths'] = {
        'local': localDocument.filePaths,
        'remote': remoteDocument.filePaths,
      };
    }

    return differences;
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Manages version conflicts and provides resolution strategies
class VersionConflictManager {
  static final VersionConflictManager _instance =
      VersionConflictManager._internal();
  factory VersionConflictManager() => _instance;
  VersionConflictManager._internal();

  final Map<String, VersionConflict> _activeConflicts = {};

  /// Detect and register a version conflict
  VersionConflict detectConflict(
    String documentId,
    Document localDocument,
    Document remoteDocument,
  ) {
    final conflictId = '${documentId}_${DateTime.now().millisecondsSinceEpoch}';

    final conflict = VersionConflict(
      documentId: documentId,
      localDocument: localDocument,
      remoteDocument: remoteDocument,
      detectedAt: DateTime.now(),
      conflictId: conflictId,
    );

    _activeConflicts[documentId] = conflict;

    safePrint('Version conflict detected for document $documentId:');
    safePrint(
        'Local version: ${localDocument.version}, Remote version: ${remoteDocument.version}');
    safePrint('Differences: ${conflict.getDifferences()}');

    return conflict;
  }

  /// Resolve a version conflict using the specified strategy
  /// Returns the resolved document that should be used
  Document resolveConflict(
    String documentId,
    ConflictResolutionStrategy strategy, {
    Document? mergedDocument,
  }) {
    final conflict = _activeConflicts[documentId];
    if (conflict == null) {
      throw Exception('No active conflict found for document $documentId');
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
        if (mergedDocument == null) {
          throw ArgumentError(
              'Merged document must be provided for merge strategy');
        }
        resolvedDocument = _resolveMerge(conflict, mergedDocument);
        break;
      case ConflictResolutionStrategy.createBranch:
        resolvedDocument = _resolveCreateBranch(conflict);
        break;
    }

    // Remove the conflict from active conflicts
    _activeConflicts.remove(documentId);

    safePrint(
        'Version conflict resolved for document $documentId using strategy: $strategy');
    return resolvedDocument;
  }

  /// Get all active conflicts
  List<VersionConflict> getActiveConflicts() {
    return _activeConflicts.values.toList();
  }

  /// Get a specific conflict by document ID
  VersionConflict? getConflict(String documentId) {
    return _activeConflicts[documentId];
  }

  /// Check if a document has an active conflict
  bool hasConflict(String documentId) {
    return _activeConflicts.containsKey(documentId);
  }

  /// Clear all active conflicts (useful for testing or reset)
  void clearConflicts() {
    _activeConflicts.clear();
    safePrint('All version conflicts cleared');
  }

  /// Auto-resolve conflicts based on simple rules
  Document? autoResolveConflict(String documentId) {
    final conflict = _activeConflicts[documentId];
    if (conflict == null) {
      return null;
    }

    // Simple auto-resolution rules:
    // 1. If only metadata changed (not content), prefer the most recent
    // 2. If file paths changed, merge them
    // 3. Otherwise, require manual resolution

    final differences = conflict.getDifferences();

    // If only title or category changed, prefer the most recent
    if (differences.length == 1 &&
        (differences.containsKey('title') ||
            differences.containsKey('category'))) {
      final localTime = conflict.localDocument.lastModified;
      final remoteTime = conflict.remoteDocument.lastModified;

      if (localTime.getDateTimeInUtc().isAfter(remoteTime.getDateTimeInUtc())) {
        return resolveConflict(
            documentId, ConflictResolutionStrategy.keepLocal);
      } else {
        return resolveConflict(
            documentId, ConflictResolutionStrategy.keepRemote);
      }
    }

    // If file paths changed, try to merge them
    if (differences.length == 1 && differences.containsKey('filePaths')) {
      final localPaths = Set<String>.from(conflict.localDocument.filePaths);
      final remotePaths = Set<String>.from(conflict.remoteDocument.filePaths);
      final mergedPaths = localPaths.union(remotePaths).toList();

      final mergedDocument = conflict.localDocument.copyWith(
        filePaths: mergedPaths,
      );

      return resolveConflict(
        documentId,
        ConflictResolutionStrategy.merge,
        mergedDocument: mergedDocument,
      );
    }

    // For complex conflicts, require manual resolution
    safePrint('Conflict for document $documentId requires manual resolution');
    return null;
  }

  /// Get conflict statistics
  Map<String, dynamic> getConflictStats() {
    final conflicts = _activeConflicts.values.toList();

    return {
      'totalConflicts': conflicts.length,
      'oldestConflict': conflicts.isEmpty
          ? null
          : conflicts
              .map((c) => c.detectedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b),
      'newestConflict': conflicts.isEmpty
          ? null
          : conflicts
              .map((c) => c.detectedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b),
      'conflictsByDocument': conflicts.map((c) => c.documentId).toList(),
    };
  }

  // Private resolution methods

  Document _resolveKeepLocal(VersionConflict conflict) {
    // Return the local document with incremented version for sync
    final resolvedDocument = conflict.localDocument.copyWith(
      version: conflict.remoteDocument.version + 1,
      lastModified: TemporalDateTime.now(),
      syncState: SyncState.synced.toJson(),
      conflictId: null, // Clear conflict ID
    );

    return resolvedDocument;
  }

  Document _resolveKeepRemote(VersionConflict conflict) {
    // Use the remote document as-is, just clear conflict state
    final resolvedDocument = conflict.remoteDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null, // Clear conflict ID
    );

    return resolvedDocument;
  }

  Document _resolveMerge(VersionConflict conflict, Document mergedDocument) {
    // Use the provided merged document with incremented version
    final resolvedDocument = mergedDocument.copyWith(
      version: conflict.remoteDocument.version + 1,
      lastModified: TemporalDateTime.now(),
      syncState: SyncState.synced.toJson(),
      conflictId: null, // Clear conflict ID
    );

    return resolvedDocument;
  }

  Document _resolveCreateBranch(VersionConflict conflict) {
    // For branch strategy, return the remote document as the main version
    // The caller is responsible for creating the branch document separately
    final resolvedDocument = conflict.remoteDocument.copyWith(
      syncState: SyncState.synced.toJson(),
      conflictId: null,
    );

    return resolvedDocument;
  }
}
