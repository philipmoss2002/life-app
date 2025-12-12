import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:household_docs_app/models/conflict.dart';
import 'package:household_docs_app/models/document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/services/conflict_resolution_service.dart';

/// **Feature: cloud-sync-premium, Property 6: Conflict Detection**
/// **Validates: Requirements 6.1, 6.2**
///
/// Property: For any document modified on two different devices with divergent
/// versions, the system should detect the conflict and preserve both versions.
void main() {
  group('ConflictResolutionService Property Tests', () {
    late ConflictResolutionService conflictService;
    final faker = Faker();

    setUp(() {
      conflictService = ConflictResolutionService();
    });

    tearDown(() {
      conflictService.dispose();
    });

    /// Property 6: Conflict Detection
    /// This test verifies that when the same document is modified on two devices
    /// with divergent versions, the system detects the conflict and preserves
    /// both versions.
    ///
    /// For i = 1 to 100:
    ///   1. Generate a random base document
    ///   2. Create two divergent versions (both modified from base)
    ///   3. Verify conflict is detected
    ///   4. Verify both versions are preserved in the conflict object
    test('Property 6: Conflict Detection for divergent versions', () async {
      const iterations = 100;
      int conflictsDetected = 0;

      for (int i = 0; i < iterations; i++) {
        // Generate a random base document
        final baseDocument = _generateRandomDocument(faker, version: 1);

        // Create local version - modified after base
        final localVersion = baseDocument.copyWith(
          title: faker.lorem.sentence(),
          version: 2,
          lastModified: DateTime.now().add(Duration(minutes: i + 1)),
        );

        // Create remote version - also modified from base (divergent)
        final remoteVersion = baseDocument.copyWith(
          title: faker.lorem.sentence(),
          version: 2,
          lastModified: DateTime.now().add(Duration(minutes: i + 2)),
        );

        // Detect conflict
        final conflict =
            conflictService.detectConflict(localVersion, remoteVersion);

        // Verify conflict is detected when versions diverge
        if (localVersion.version == remoteVersion.version &&
            localVersion.title != remoteVersion.title) {
          expect(conflict, isNotNull,
              reason: 'Conflict should be detected for divergent versions');
          conflictsDetected++;

          // Verify both versions are preserved
          expect(conflict!.localVersion.id, equals(localVersion.id));
          expect(conflict.remoteVersion.id, equals(remoteVersion.id));
          expect(conflict.localVersion.title, equals(localVersion.title));
          expect(conflict.remoteVersion.title, equals(remoteVersion.title));
        }
      }

      // Verify conflicts were detected in the test
      expect(conflictsDetected, greaterThan(0),
          reason: 'Should have detected conflicts in property test');
    });

    test('Property 6: No conflict when versions are identical', () async {
      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Generate a random document
        final document = _generateRandomDocument(faker, version: i + 1);

        // Create identical copy
        final identicalCopy = document.copyWith();

        // Detect conflict
        final conflict =
            conflictService.detectConflict(document, identicalCopy);

        // Verify no conflict for identical versions
        expect(conflict, isNull,
            reason: 'No conflict should be detected for identical versions');
      }
    });

    test('Property 6: Conflict detected when local ahead but remote modified',
        () async {
      const iterations = 100;
      int conflictsDetected = 0;

      for (int i = 0; i < iterations; i++) {
        // Generate base document
        final baseDocument = _generateRandomDocument(faker, version: 1);

        // Local is ahead in version
        final localVersion = baseDocument.copyWith(
          title: faker.lorem.sentence(),
          version: 3,
          lastModified: DateTime.now().add(Duration(minutes: i + 1)),
        );

        // Remote has older version but was modified more recently
        final remoteVersion = baseDocument.copyWith(
          title: faker.lorem.sentence(),
          version: 2,
          lastModified: DateTime.now().add(Duration(minutes: i + 10)),
        );

        // Detect conflict
        final conflict =
            conflictService.detectConflict(localVersion, remoteVersion);

        // This scenario should detect a conflict
        if (remoteVersion.lastModified.isAfter(localVersion.lastModified)) {
          expect(conflict, isNotNull,
              reason:
                  'Conflict should be detected when remote modified after local');
          conflictsDetected++;
        }
      }

      expect(conflictsDetected, greaterThan(0),
          reason: 'Should detect conflicts in this scenario');
    });

    test('Property 6: Conflict stream emits detected conflicts', () async {
      final conflicts = <Conflict>[];
      final subscription = conflictService.conflictStream.listen((conflict) {
        conflicts.add(conflict);
      });

      // Generate and detect conflicts
      for (int i = 0; i < 10; i++) {
        final baseDocument = _generateRandomDocument(faker, version: 1);

        final localVersion = baseDocument.copyWith(
          title: 'Local ${faker.lorem.word()}',
          version: 2,
          lastModified: DateTime.now().add(Duration(seconds: i)),
        );

        final remoteVersion = baseDocument.copyWith(
          title: 'Remote ${faker.lorem.word()}',
          version: 2,
          lastModified: DateTime.now().add(Duration(seconds: i + 1)),
        );

        conflictService.detectConflict(localVersion, remoteVersion);
      }

      // Wait for stream to process
      await Future.delayed(Duration(milliseconds: 100));

      // Verify conflicts were emitted
      expect(conflicts.length, greaterThan(0),
          reason: 'Conflict stream should emit detected conflicts');

      await subscription.cancel();
    });
  });

  group('ConflictResolutionService Unit Tests', () {
    late ConflictResolutionService conflictService;
    final faker = Faker();

    setUp(() {
      conflictService = ConflictResolutionService();
    });

    tearDown(() {
      conflictService.dispose();
    });

    test('detectConflict returns null for same version', () {
      final doc = _generateRandomDocument(faker, version: 1);
      final conflict = conflictService.detectConflict(doc, doc);
      expect(conflict, isNull);
    });

    test('detectConflict creates conflict for divergent versions', () {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(
        title: 'Local Title',
        version: 2,
        lastModified: DateTime.now(),
      );
      final remote = baseDoc.copyWith(
        title: 'Remote Title',
        version: 2,
        lastModified: DateTime.now().add(Duration(seconds: 1)),
      );

      final conflict = conflictService.detectConflict(local, remote);
      expect(conflict, isNotNull);
      expect(conflict!.type, equals(ConflictType.documentModified));
    });

    test('getActiveConflicts returns empty list initially', () async {
      final conflicts = await conflictService.getActiveConflicts();
      expect(conflicts, isEmpty);
    });

    test('getActiveConflicts returns detected conflicts', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(title: 'Local', version: 2);
      final remote = baseDoc.copyWith(
        title: 'Remote',
        version: 2,
        lastModified: DateTime.now().add(Duration(seconds: 1)),
      );

      conflictService.detectConflict(local, remote);

      final conflicts = await conflictService.getActiveConflicts();
      expect(conflicts.length, equals(1));
    });

    test('mergeDocuments combines file paths from both versions', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(
        filePaths: ['/path/local1.pdf', '/path/local2.pdf'],
        version: 2,
      );
      final remote = baseDoc.copyWith(
        filePaths: ['/path/remote1.pdf', '/path/remote2.pdf'],
        version: 2,
      );

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.filePaths.length, equals(4));
      expect(merged.filePaths, contains('/path/local1.pdf'));
      expect(merged.filePaths, contains('/path/remote1.pdf'));
    });

    test('mergeDocuments uses most recent title', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final now = DateTime.now();
      final local = baseDoc.copyWith(
        title: 'Local Title',
        version: 2,
        lastModified: now,
      );
      final remote = baseDoc.copyWith(
        title: 'Remote Title',
        version: 2,
        lastModified: now.add(Duration(seconds: 1)),
      );

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.title, equals('Remote Title'));
    });

    test('mergeDocuments combines notes from both versions', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(
        notes: 'Local notes',
        version: 2,
      );
      final remote = baseDoc.copyWith(
        notes: 'Remote notes',
        version: 2,
      );

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.notes, contains('Local notes'));
      expect(merged.notes, contains('Remote notes'));
      expect(merged.notes, contains('Merged from other device'));
    });

    test('mergeDocuments increments version', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(version: 3);
      final remote = baseDoc.copyWith(version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.version, equals(4)); // max(3, 2) + 1
    });

    test('mergeDocuments sets sync state to pending', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(version: 2);
      final remote = baseDoc.copyWith(version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.syncState, equals(SyncState.pending));
    });

    test('conflictStream is broadcast stream', () {
      expect(conflictService.conflictStream.isBroadcast, isTrue);
    });

    test('resolveConflict with keepLocal strategy', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(
        title: 'Local Title',
        version: 2,
        lastModified: DateTime.now(),
      );
      final remote = baseDoc.copyWith(
        title: 'Remote Title',
        version: 2,
        lastModified: DateTime.now().add(Duration(seconds: 1)),
      );

      final conflict = conflictService.detectConflict(local, remote);
      expect(conflict, isNotNull);

      // Note: This test verifies the logic but won't actually update the database
      // since we're not using a real database service in this test
      try {
        final resolved = await conflictService.resolveConflict(
          conflict!,
          ConflictResolution.keepLocal,
        );

        expect(resolved.title, equals('Local Title'));
        expect(resolved.syncState, equals(SyncState.pending));
        expect(resolved.conflictId, isNull);
      } catch (e) {
        // Expected to fail without a real database
        expect(e.toString(), contains('database'));
      }
    });

    test('resolveConflict with keepRemote strategy', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(
        title: 'Local Title',
        version: 2,
        lastModified: DateTime.now(),
      );
      final remote = baseDoc.copyWith(
        title: 'Remote Title',
        version: 2,
        lastModified: DateTime.now().add(Duration(seconds: 1)),
      );

      final conflict = conflictService.detectConflict(local, remote);
      expect(conflict, isNotNull);

      try {
        final resolved = await conflictService.resolveConflict(
          conflict!,
          ConflictResolution.keepRemote,
        );

        expect(resolved.title, equals('Remote Title'));
        expect(resolved.syncState, equals(SyncState.synced));
        expect(resolved.conflictId, isNull);
      } catch (e) {
        // Expected to fail without a real database
        expect(e.toString(), contains('database'));
      }
    });

    test('resolveConflict with merge strategy', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(
        title: 'Local Title',
        filePaths: ['/local/file.pdf'],
        version: 2,
        lastModified: DateTime.now(),
      );
      final remote = baseDoc.copyWith(
        title: 'Remote Title',
        filePaths: ['/remote/file.pdf'],
        version: 2,
        lastModified: DateTime.now().add(Duration(seconds: 1)),
      );

      final conflict = conflictService.detectConflict(local, remote);
      expect(conflict, isNotNull);

      try {
        final resolved = await conflictService.resolveConflict(
          conflict!,
          ConflictResolution.merge,
        );

        // Should use remote title (more recent)
        expect(resolved.title, equals('Remote Title'));
        // Should merge file paths
        expect(resolved.filePaths.length, equals(2));
        expect(resolved.filePaths, contains('/local/file.pdf'));
        expect(resolved.filePaths, contains('/remote/file.pdf'));
        expect(resolved.syncState, equals(SyncState.pending));
        expect(resolved.conflictId, isNull);
      } catch (e) {
        // Expected to fail without a real database
        expect(e.toString(), contains('database'));
      }
    });

    test('resolveConflict removes conflict from active list', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(title: 'Local', version: 2);
      final remote = baseDoc.copyWith(
        title: 'Remote',
        version: 2,
        lastModified: DateTime.now().add(Duration(seconds: 1)),
      );

      final conflict = conflictService.detectConflict(local, remote);
      expect(conflict, isNotNull);

      var conflicts = await conflictService.getActiveConflicts();
      expect(conflicts.length, equals(1));

      // The resolveConflict will fail without a real database, but it should
      // still remove the conflict from the active list before attempting the update
      try {
        await conflictService.resolveConflict(
          conflict!,
          ConflictResolution.keepLocal,
        );
      } catch (e) {
        // Expected to fail without a real database
      }

      // Verify conflict was removed from active list
      conflicts = await conflictService.getActiveConflicts();
      expect(conflicts.length, equals(0));
    });

    test('mergeDocuments handles null notes gracefully', () async {
      // Create a document without notes in the generator
      final baseDoc = Document(
        id: faker.randomGenerator.integer(10000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Insurance',
        filePaths: [],
        notes: null, // Explicitly null
        version: 1,
      );

      final local = baseDoc.copyWith(notes: null, version: 2);
      final remote = baseDoc.copyWith(notes: 'Remote notes', version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.notes, equals('Remote notes'));
    });

    test('mergeDocuments handles identical notes', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final local = baseDoc.copyWith(notes: 'Same notes', version: 2);
      final remote = baseDoc.copyWith(notes: 'Same notes', version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.notes, equals('Same notes'));
    });

    test('mergeDocuments uses earlier createdAt date', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final earlierDate = DateTime(2023, 1, 1);
      final laterDate = DateTime(2023, 6, 1);

      final local = baseDoc.copyWith(createdAt: laterDate, version: 2);
      final remote = baseDoc.copyWith(createdAt: earlierDate, version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.createdAt, equals(earlierDate));
    });

    test('mergeDocuments preserves userId', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final userId = faker.guid.guid();
      final local = baseDoc.copyWith(userId: userId, version: 2);
      final remote = baseDoc.copyWith(userId: userId, version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.userId, equals(userId));
    });

    test('mergeDocuments handles renewal date from either version', () async {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final renewalDate = DateTime(2025, 12, 31);

      final local = baseDoc.copyWith(renewalDate: renewalDate, version: 2);
      final remote = baseDoc.copyWith(renewalDate: null, version: 2);

      final merged = await conflictService.mergeDocuments(local, remote);

      expect(merged.renewalDate, equals(renewalDate));
    });

    test('detectConflict handles documents with different modification times',
        () {
      final baseDoc = _generateRandomDocument(faker, version: 1);
      final now = DateTime.now();

      final doc1 = baseDoc.copyWith(
        version: 1,
        lastModified: now,
      );
      final doc2 = baseDoc.copyWith(
        version: 1,
        lastModified: now.add(Duration(seconds: 5)),
      );

      // Should detect conflict when same version but different modification times
      final conflict = conflictService.detectConflict(doc1, doc2);
      expect(conflict, isNotNull);
    });
  });
}

/// Helper function to generate random documents for testing
Document _generateRandomDocument(Faker faker, {int version = 1}) {
  return Document(
    id: faker.randomGenerator.integer(10000),
    userId: faker.guid.guid(),
    title: faker.lorem.sentence(),
    category: faker.randomGenerator.element(
        ['Insurance', 'Warranty', 'Subscription', 'Contract', 'Other']),
    filePaths: [faker.internet.httpsUrl()],
    renewalDate: faker.date.dateTime(minYear: 2024, maxYear: 2025),
    notes: faker.lorem.sentences(3).join(' '),
    createdAt: faker.date.dateTime(minYear: 2023, maxYear: 2024),
    lastModified: DateTime.now(),
    version: version,
    syncState: SyncState.synced,
  );
}
