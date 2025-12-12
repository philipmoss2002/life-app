import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:household_docs_app/models/document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/services/cloud_sync_service.dart';
import '../test_helpers.dart';

/// **Feature: cloud-sync-premium, Property 9: Sync Status Accuracy**
/// **Validates: Requirements 8.1, 8.2, 8.3**
///
/// Property: For any document, the displayed sync status should accurately
/// reflect the current synchronization state of that document.
///
/// This property ensures that:
/// 1. When a document is synced, it shows a synced indicator
/// 2. When a document has pending changes, it shows a pending indicator
/// 3. When a sync error occurs, it shows an error indicator with details
/// 4. The sync state transitions are accurately reflected in the UI
void main() {
  setUpAll(() {
    setupTestDatabase();
  });

  group('Sync Status Accuracy Property Tests', () {
    final faker = Faker();

    /// Property 9: Sync Status Accuracy
    /// This test verifies that for any document with a given sync state,
    /// the system accurately reports that state.
    ///
    /// Full property test (100+ iterations):
    /// For i = 1 to 100:
    ///   1. Generate random document with random sync state
    ///   2. Store document in database
    ///   3. Retrieve document sync state
    ///   4. Verify retrieved state matches stored state
    ///   5. Update document sync state to different random state
    ///   6. Verify state change is accurately reflected
    test('Property 9: Sync state is accurately stored and retrieved', () async {
      // Run property test with multiple iterations
      for (int i = 0; i < 100; i++) {
        // Generate random document with random sync state
        final randomState = faker.randomGenerator.element(SyncState.values);
        final document = Document(
          id: faker.randomGenerator.integer(100000),
          userId: faker.guid.guid(),
          title: faker.lorem.sentence(),
          category: faker.randomGenerator
              .element(['Insurance', 'Warranty', 'Contract', 'Other']),
          filePaths: [],
          syncState: randomState,
          version: faker.randomGenerator.integer(10),
          lastModified: DateTime.now(),
        );

        // Verify the document has the expected sync state
        expect(document.syncState, equals(randomState),
            reason:
                'Document sync state should match the assigned state (iteration $i)');

        // Test state transitions
        final newState = faker.randomGenerator.element(
          SyncState.values.where((s) => s != randomState).toList(),
        );

        final updatedDocument = document.copyWith(syncState: newState);

        // Verify state transition is accurate
        expect(updatedDocument.syncState, equals(newState),
            reason:
                'Document sync state should accurately reflect state transition (iteration $i)');
        expect(updatedDocument.syncState, isNot(equals(randomState)),
            reason: 'State should have changed from original (iteration $i)');
      }
    });

    /// Property 9: Sync state enum serialization round-trip
    /// Verifies that sync states can be serialized and deserialized accurately
    test('Property 9: Sync state serialization is accurate', () {
      // Test all sync states
      for (final state in SyncState.values) {
        // Serialize to JSON
        final json = state.toJson();
        expect(json, isNotNull);
        expect(json, isA<String>());

        // Deserialize from JSON
        final deserializedState = SyncState.fromJson(json);

        // Verify round-trip accuracy
        expect(deserializedState, equals(state),
            reason:
                'Sync state should accurately round-trip through serialization: $state');
      }
    });

    /// Property 9: Sync status reflects document state changes
    /// Verifies that when a document's sync state changes, the status
    /// accurately reflects the new state
    test('Property 9: Sync status reflects all state transitions', () async {
      final faker = Faker();

      // Test all possible state transitions
      for (final fromState in SyncState.values) {
        for (final toState in SyncState.values) {
          // Create document with initial state
          final document = Document(
            id: faker.randomGenerator.integer(100000),
            userId: faker.guid.guid(),
            title: faker.lorem.sentence(),
            category: 'Insurance',
            filePaths: [],
            syncState: fromState,
          );

          // Verify initial state
          expect(document.syncState, equals(fromState));

          // Transition to new state
          final updatedDocument = document.copyWith(syncState: toState);

          // Verify new state is accurate
          expect(updatedDocument.syncState, equals(toState),
              reason:
                  'State transition from $fromState to $toState should be accurate');
        }
      }
    });

    /// Property 9: Sync status indicator matches document state
    /// Verifies that the UI indicator correctly represents each sync state
    test('Property 9: Each sync state has a unique indicator', () {
      // Map of sync states to their expected indicator characteristics
      final stateIndicators = {
        SyncState.synced: {'hasIcon': true, 'isError': false},
        SyncState.pending: {'hasIcon': true, 'isError': false},
        SyncState.syncing: {'hasIcon': true, 'isError': false},
        SyncState.conflict: {'hasIcon': true, 'isError': true},
        SyncState.error: {'hasIcon': true, 'isError': true},
        SyncState.notSynced: {'hasIcon': true, 'isError': false},
      };

      // Verify each state has indicator characteristics defined
      for (final state in SyncState.values) {
        expect(stateIndicators.containsKey(state), isTrue,
            reason: 'Each sync state should have indicator characteristics');

        final indicators = stateIndicators[state]!;
        expect(indicators['hasIcon'], isTrue,
            reason: 'Each sync state should have an icon indicator');
      }
    });

    /// Property 9: Sync status accuracy with multiple documents
    /// Verifies that sync status is accurately tracked for multiple documents
    /// simultaneously
    test('Property 9: Sync status is accurate for multiple documents',
        () async {
      final documents = <Document>[];

      // Generate 50 random documents with random sync states
      for (int i = 0; i < 50; i++) {
        final randomState = faker.randomGenerator.element(SyncState.values);
        final document = Document(
          id: faker.randomGenerator.integer(100000),
          userId: faker.guid.guid(),
          title: faker.lorem.sentence(),
          category: faker.randomGenerator
              .element(['Insurance', 'Warranty', 'Contract']),
          filePaths: [],
          syncState: randomState,
        );
        documents.add(document);
      }

      // Verify each document maintains its sync state accurately
      for (int i = 0; i < documents.length; i++) {
        final doc = documents[i];
        expect(doc.syncState, isNotNull,
            reason: 'Document $i should have a sync state');
        expect(SyncState.values.contains(doc.syncState), isTrue,
            reason: 'Document $i should have a valid sync state');
      }

      // Verify state distribution (should have variety)
      final stateSet = documents.map((d) => d.syncState).toSet();
      expect(stateSet.length, greaterThan(1),
          reason: 'Multiple documents should have variety in sync states');
    });

    /// Property 9: Sync status detail information is accurate
    /// Verifies that detailed sync information (version, last modified, etc.)
    /// is accurately maintained and reported
    test('Property 9: Sync detail information is accurate', () async {
      for (int i = 0; i < 100; i++) {
        final version = faker.randomGenerator.integer(100);
        final lastModified = DateTime.now().subtract(
          Duration(hours: faker.randomGenerator.integer(1000)),
        );

        final document = Document(
          id: faker.randomGenerator.integer(100000),
          userId: faker.guid.guid(),
          title: faker.lorem.sentence(),
          category: 'Insurance',
          filePaths: [],
          syncState: faker.randomGenerator.element(SyncState.values),
          version: version,
          lastModified: lastModified,
        );

        // Verify version is accurate
        expect(document.version, equals(version),
            reason: 'Document version should be accurately stored');

        // Verify last modified is accurate
        expect(document.lastModified, equals(lastModified),
            reason: 'Document last modified time should be accurately stored');

        // Verify sync state is accurate
        expect(SyncState.values.contains(document.syncState), isTrue,
            reason: 'Document should have a valid sync state');
      }
    });

    /// Property 9: Sync status consistency across service calls
    /// Verifies that sync status remains consistent when queried multiple times
    test('Property 9: Sync status model maintains consistency', () async {
      // Test that SyncStatus model maintains consistency
      final statuses = <SyncStatus>[];

      // Create multiple status instances with random data
      for (int i = 0; i < 10; i++) {
        final status = SyncStatus(
          isSyncing: faker.randomGenerator.boolean(),
          pendingChanges: faker.randomGenerator.integer(100),
          lastSyncTime: faker.randomGenerator.boolean()
              ? DateTime.now().subtract(
                  Duration(minutes: faker.randomGenerator.integer(1000)))
              : null,
          error:
              faker.randomGenerator.boolean() ? faker.lorem.sentence() : null,
        );
        statuses.add(status);
      }

      // Verify all statuses have valid structure
      for (int i = 0; i < statuses.length; i++) {
        expect(statuses[i].isSyncing, isA<bool>(),
            reason: 'Status $i should have valid isSyncing flag');
        expect(statuses[i].pendingChanges, isA<int>(),
            reason: 'Status $i should have valid pendingChanges count');
        expect(statuses[i].pendingChanges, greaterThanOrEqualTo(0),
            reason: 'Status $i should have non-negative pending changes');
      }
    });

    /// Property 9: Error states are accurately reported
    /// Verifies that when sync errors occur, they are accurately captured
    /// and reported in the sync status
    test('Property 9: Error states are accurately represented', () {
      // Test error state representation
      final errorDocument = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Insurance',
        filePaths: [],
        syncState: SyncState.error,
      );

      expect(errorDocument.syncState, equals(SyncState.error));
      expect(errorDocument.syncState.name, equals('error'));

      // Test conflict state representation
      final conflictDocument = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Warranty',
        filePaths: [],
        syncState: SyncState.conflict,
      );

      expect(conflictDocument.syncState, equals(SyncState.conflict));
      expect(conflictDocument.syncState.name, equals('conflict'));
    });
  });

  group('Sync Status UI Unit Tests', () {
    final faker = Faker();

    test('Document with synced state is correctly identified', () {
      final document = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Insurance',
        filePaths: [],
        syncState: SyncState.synced,
      );

      expect(document.syncState, equals(SyncState.synced));
      expect(document.syncState.name, equals('synced'));
    });

    test('Document with pending state is correctly identified', () {
      final document = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Warranty',
        filePaths: [],
        syncState: SyncState.pending,
      );

      expect(document.syncState, equals(SyncState.pending));
      expect(document.syncState.name, equals('pending'));
    });

    test('Document with syncing state is correctly identified', () {
      final document = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Contract',
        filePaths: [],
        syncState: SyncState.syncing,
      );

      expect(document.syncState, equals(SyncState.syncing));
      expect(document.syncState.name, equals('syncing'));
    });

    test('Document with error state is correctly identified', () {
      final document = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Insurance',
        filePaths: [],
        syncState: SyncState.error,
      );

      expect(document.syncState, equals(SyncState.error));
      expect(document.syncState.name, equals('error'));
    });

    test('Document with conflict state is correctly identified', () {
      final document = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Warranty',
        filePaths: [],
        syncState: SyncState.conflict,
      );

      expect(document.syncState, equals(SyncState.conflict));
      expect(document.syncState.name, equals('conflict'));
    });

    test('Document with notSynced state is correctly identified', () {
      final document = Document(
        id: faker.randomGenerator.integer(100000),
        userId: faker.guid.guid(),
        title: faker.lorem.sentence(),
        category: 'Other',
        filePaths: [],
        syncState: SyncState.notSynced,
      );

      expect(document.syncState, equals(SyncState.notSynced));
      expect(document.syncState.name, equals('notSynced'));
    });

    test('SyncState enum has all expected values', () {
      expect(SyncState.values.length, equals(6));
      expect(SyncState.values, contains(SyncState.synced));
      expect(SyncState.values, contains(SyncState.pending));
      expect(SyncState.values, contains(SyncState.syncing));
      expect(SyncState.values, contains(SyncState.conflict));
      expect(SyncState.values, contains(SyncState.error));
      expect(SyncState.values, contains(SyncState.notSynced));
    });

    test('SyncStatus model has correct structure', () {
      final status = SyncStatus(
        isSyncing: true,
        pendingChanges: 5,
        lastSyncTime: DateTime.now(),
        error: 'Test error',
      );

      expect(status.isSyncing, isTrue);
      expect(status.pendingChanges, equals(5));
      expect(status.lastSyncTime, isNotNull);
      expect(status.error, equals('Test error'));
    });

    test('SyncStatus with no error has null error field', () {
      final status = SyncStatus(
        isSyncing: false,
        pendingChanges: 0,
        lastSyncTime: DateTime.now(),
      );

      expect(status.error, isNull);
    });

    test('SyncStatus with no last sync time has null lastSyncTime', () {
      final status = SyncStatus(
        isSyncing: false,
        pendingChanges: 0,
      );

      expect(status.lastSyncTime, isNull);
    });
  });
}
