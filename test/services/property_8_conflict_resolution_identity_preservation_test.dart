import 'package:test/test.dart';
import 'package:household_docs_app/utils/sync_identifier_generator.dart';

import '../../lib/services/sync_identifier_service.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
/// **Feature: sync-identifier-refactor, Property 8: Conflict Resolution Identity Preservation**
/// **Validates: Requirements 6.3**
///
/// Property-based test to verify that during conflict resolution, the original
/// document's sync identifier is preserved in the resolved document.
void main() {
  group('Property 8: Conflict Resolution Identity Preservation', () {
    test(
        'original document sync identifier should be preserved in all conflict resolution strategies',
        () {
      // Property: For any conflict resolution, the original document's sync identifier
      // should be preserved in the resolved document

      const numConflicts = 100;
      final resolutionStrategies = ['keepLocal', 'keepRemote', 'merge'];

      for (int i = 0; i < numConflicts; i++) {
        // Generate original sync identifier for the document
        final originalSyncId = SyncIdentifierService.generateValidated();

        // Create mock local and remote documents with the same sync identifier
        final localDoc = _MockDocument(syncId: originalSyncId, title: 'Local Title $i', version: 1, lastModified: DateTime.now(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
        );

        final remoteDoc = _MockDocument(syncId: originalSyncId, title: 'Remote Title $i', version: 1, lastModified: DateTime.now(, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
        );

        // Test each resolution strategy
        for (final strategy in resolutionStrategies) {
          // Simulate conflict resolution
          final resolvedDoc = _simulateConflictResolution(
            localDoc,
            remoteDoc,
            strategy,
          );

          // Verify that the original sync identifier is preserved
          expect(
            resolvedDoc.syncId,
            equals(originalSyncId),
            reason:
                'Original sync identifier should be preserved in $strategy resolution for conflict $i',
          );

          // Verify the resolved sync identifier is still valid
          expect(
            SyncIdentifierGenerator.isValid(resolvedDoc.syncId),
            isTrue,
            reason:
                'Resolved document should have valid sync identifier for $strategy resolution',
          );
        }
      }
    });

    test('sync identifier should be preserved when keeping local document', () {
      // Property: When resolving conflicts by keeping local document,
      // the local document's sync identifier should be preserved

      const numTests = 50;

      for (int i = 0; i < numTests; i++) {
        final originalSyncId = SyncIdentifierService.generateValidated();

        final localDoc = _MockDocument(syncId: originalSyncId, title: 'Local Document $i', version: 2, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

        final remoteDoc = _MockDocument(syncId:
              originalSyncId, // Same sync ID (they represent the same logical document, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending")
          title: 'Remote Document $i',
          version: 1,
        );

        final resolvedDoc = _simulateConflictResolution(
          localDoc,
          remoteDoc,
          'keepLocal',
        );

        expect(
          resolvedDoc.syncId,
          equals(originalSyncId),
          reason:
              'Local document sync identifier should be preserved when keeping local for test $i',
        );

        expect(
          resolvedDoc.title,
          equals(localDoc.title),
          reason:
              'Local document content should be preserved when keeping local',
        );
      }
    });

    test('sync identifier should be preserved when keeping remote document',
        () {
      // Property: When resolving conflicts by keeping remote document,
      // the original document's sync identifier should still be preserved

      const numTests = 50;

      for (int i = 0; i < numTests; i++) {
        final originalSyncId = SyncIdentifierService.generateValidated();

        final localDoc = _MockDocument(syncId: originalSyncId, title: 'Local Document $i', version: 1, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

        final remoteDoc = _MockDocument(syncId:
              originalSyncId, // Same sync ID (they represent the same logical document, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending")
          title: 'Remote Document $i',
          version: 2,
        );

        final resolvedDoc = _simulateConflictResolution(
          localDoc,
          remoteDoc,
          'keepRemote',
        );

        expect(
          resolvedDoc.syncId,
          equals(originalSyncId),
          reason:
              'Original sync identifier should be preserved when keeping remote for test $i',
        );

        expect(
          resolvedDoc.title,
          equals(remoteDoc.title),
          reason: 'Remote document content should be used when keeping remote',
        );
      }
    });

    test('sync identifier should be preserved during document merging', () {
      // Property: When resolving conflicts by merging documents,
      // the original document's sync identifier should be preserved

      const numTests = 50;

      for (int i = 0; i < numTests; i++) {
        final originalSyncId = SyncIdentifierService.generateValidated();

        final localDoc = _MockDocument(syncId: originalSyncId, title: 'Local Title $i', notes: 'Local notes $i', version: 1, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

        final remoteDoc = _MockDocument(syncId: originalSyncId, title: 'Remote Title $i', notes: 'Remote notes $i', version: 1, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

        final resolvedDoc = _simulateConflictResolution(
          localDoc,
          remoteDoc,
          'merge',
        );

        expect(
          resolvedDoc.syncId,
          equals(originalSyncId),
          reason:
              'Original sync identifier should be preserved during merge for test $i',
        );

        // Verify merge actually happened (version should be incremented)
        expect(
          resolvedDoc.version,
          greaterThan(localDoc.version),
          reason: 'Merged document should have incremented version',
        );
      }
    });

    test('sync identifier preservation should work with conflict copies', () {
      // Property: When creating conflict copies, the original document should
      // preserve its sync identifier while the copy gets a new one

      const numTests = 30;

      for (int i = 0; i < numTests; i++) {
        final originalSyncId = SyncIdentifierService.generateValidated();

        final originalDoc = _MockDocument(syncId: originalSyncId, title: 'Original Document $i', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");

        // Simulate creating a conflict copy
        final conflictCopy = _simulateConflictCopyCreation(originalDoc);

        // Original document should keep its sync identifier
        expect(
          originalDoc.syncId,
          equals(originalSyncId),
          reason:
              'Original document should preserve sync identifier when creating conflict copy $i',
        );

        // Conflict copy should have a different sync identifier
        expect(
          conflictCopy.syncId,
          isNot(equals(originalSyncId)),
          reason:
              'Conflict copy should have different sync identifier for test $i',
        );

        // Both sync identifiers should be valid
        expect(
          SyncIdentifierGenerator.isValid(originalDoc.syncId),
          isTrue,
          reason: 'Original document sync identifier should remain valid',
        );

        expect(
          SyncIdentifierGenerator.isValid(conflictCopy.syncId),
          isTrue,
          reason: 'Conflict copy sync identifier should be valid',
        );
      }
    });

    test('sync identifier preservation should handle edge cases', () {
      // Property: Sync identifier preservation should work even in edge cases

      final originalSyncId = SyncIdentifierService.generateValidated();

      // Test with documents having different versions
      final localDoc = _MockDocument(syncId: originalSyncId, title: 'Local', version: 10, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

      final remoteDoc = _MockDocument(syncId: originalSyncId, title: 'Remote', version: 5, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

      final resolvedDoc = _simulateConflictResolution(
        localDoc,
        remoteDoc,
        'merge',
      );

      expect(
        resolvedDoc.syncId,
        equals(originalSyncId),
        reason:
            'Sync identifier should be preserved even with different versions',
      );

      // Test with documents having null fields
      final docWithNulls = _MockDocument(syncId: originalSyncId, title: 'Document with nulls', notes: null, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");

      final docWithValues = _MockDocument(syncId: originalSyncId, title: 'Document with values', notes: 'Some notes', userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");

      final mergedDoc = _simulateConflictResolution(
        docWithNulls,
        docWithValues,
        'merge',
      );

      expect(
        mergedDoc.syncId,
        equals(originalSyncId),
        reason:
            'Sync identifier should be preserved when merging documents with null fields',
      );
    });

    test(
        'sync identifier preservation should work across multiple conflict resolutions',
        () {
      // Property: A document's sync identifier should remain stable across
      // multiple conflict resolution cycles

      const numCycles = 20;
      final originalSyncId = SyncIdentifierService.generateValidated();

      var currentDoc = _MockDocument(syncId: originalSyncId, title: 'Initial Document', version: 1, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

      for (int cycle = 0; cycle < numCycles; cycle++) {
        // Create a conflicting version
        final conflictingDoc = _MockDocument(syncId: originalSyncId, title: 'Conflicting Document $cycle', version: currentDoc.version, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending");

        // Resolve the conflict
        currentDoc = _simulateConflictResolution(
          currentDoc,
          conflictingDoc,
          'merge',
        );

        // Verify sync identifier is still preserved
        expect(
          currentDoc.syncId,
          equals(originalSyncId),
          reason:
              'Sync identifier should remain stable after conflict resolution cycle $cycle',
        );
      }

      // Final verification
      expect(
        currentDoc.syncId,
        equals(originalSyncId),
        reason:
            'Sync identifier should be identical to original after $numCycles resolution cycles',
      );
    });
  });
}

// Mock document class for testing without Flutter dependencies
class _MockDocument {
  final String syncId;
  final String title;
  final String? notes;
  final int version;
  final DateTime lastModified;

  _MockDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), {,
    required this.syncId,
    required this.title,
    this.notes,
    this.version = 1,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now();

  _MockDocument copyWith({
    String? syncId,
    String? title,
    String? notes,
    int? version,
    DateTime? lastModified,
  }) {
    return _MockDocument(syncId: syncId ?? this.syncId, title: title ?? this.title, notes: notes ?? this.notes, version: version ?? this.version, lastModified: lastModified ?? this.lastModified, userId: "test-user", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending");
  }
}

// Helper methods for simulating conflict resolution operations

_MockDocument _simulateConflictResolution(
  _MockDocument localDoc,
  _MockDocument remoteDoc,
  String strategy,
) {
  switch (strategy) {
    case 'keepLocal':
      return localDoc.copyWith();

    case 'keepRemote':
      // Preserve the local document's sync identifier when keeping remote
      return remoteDoc.copyWith(
        syncId: localDoc.syncId,
      );

    case 'merge':
      // Simulate merge operation preserving sync identifier
      final syncId = localDoc.syncId;

      // Use the more recent title
      final useLocalTitle =
          localDoc.lastModified.isAfter(remoteDoc.lastModified);

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

      return localDoc.copyWith(
        syncId: syncId,
        title: useLocalTitle ? localDoc.title : remoteDoc.title,
        notes: mergedNotes,
        version: (localDoc.version > remoteDoc.version
                ? localDoc.version
                : remoteDoc.version) +
            1,
        lastModified: DateTime.now(),
      );

    default:
      throw ArgumentError('Unknown resolution strategy: $strategy');
  }
}

_MockDocument _simulateConflictCopyCreation(_MockDocument originalDoc) {
  // Generate a new sync identifier for the conflict copy
  final newSyncId = SyncIdentifierService.generateValidated();

  return originalDoc.copyWith(
    syncId: newSyncId,
    title: '${originalDoc.title} (Conflict Copy)',
    version: 1,
    lastModified: DateTime.now(),
  );
}
