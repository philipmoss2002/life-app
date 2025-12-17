import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/Document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/models/model_extensions.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

void main() {
  group('Document Model Tests', () {
    test('Document should be created with required fields', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Insurance',
        category: 'Home Insurance',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      expect(document.title, 'Test Insurance');
      expect(document.category, 'Home Insurance');
      expect(document.userId, 'test-user');
      expect(document.filePaths, isEmpty);
      expect(document.renewalDate, isNull);
      expect(document.notes, isNull);
      expect(document.createdAt, isNotNull);
    });

    test('Document should be created with all fields', () {
      final renewalDate = amplify_core.TemporalDateTime(DateTime(2025, 12, 31));
      final createdAt = amplify_core.TemporalDateTime(DateTime(2025, 1, 1));
      final lastModified = amplify_core.TemporalDateTime(DateTime(2025, 1, 2));

      final document = Document(
        id: 'doc-1',
        userId: 'test-user',
        title: 'Car Insurance',
        category: 'Car Insurance',
        filePaths: ['/path/to/file.pdf'],
        renewalDate: renewalDate,
        notes: 'Test notes',
        createdAt: createdAt,
        lastModified: lastModified,
        version: 1,
        syncState: SyncState.synced.toJson(),
      );

      expect(document.id, 'doc-1');
      expect(document.title, 'Car Insurance');
      expect(document.category, 'Car Insurance');
      expect(document.filePaths, ['/path/to/file.pdf']);
      expect(document.renewalDate, renewalDate);
      expect(document.notes, 'Test notes');
      expect(document.createdAt, createdAt);
    });

    test('Document should convert to map correctly', () {
      final renewalDate = amplify_core.TemporalDateTime(DateTime(2025, 12, 31));
      final createdAt = amplify_core.TemporalDateTime.now();
      final lastModified = amplify_core.TemporalDateTime.now();

      final document = Document(
        id: 'doc-1',
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Mortgage',
        filePaths: [],
        renewalDate: renewalDate,
        createdAt: createdAt,
        lastModified: lastModified,
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      final map = document.toMap();

      expect(map['id'], 'doc-1');
      expect(map['title'], 'Test Doc');
      expect(map['category'], 'Mortgage');
      expect(map['renewalDate'], renewalDate);
      expect(map['createdAt'], createdAt);
    });

    test('Document should be created from map correctly', () {
      final map = {
        'id': 'doc-1',
        'userId': 'test-user',
        'title': 'Holiday Booking',
        'category': 'Holiday',
        'filePaths': ['/path/to/file.pdf'],
        'renewalDate': '2025-12-31T00:00:00.000',
        'notes': 'Test notes',
        'createdAt': '2025-01-01T00:00:00.000',
        'lastModified': '2025-01-02T00:00:00.000',
        'version': 1,
        'syncState': 'synced',
      };

      final document = DocumentExtensions.fromMap(map);

      expect(document.id, 'doc-1');
      expect(document.title, 'Holiday Booking');
      expect(document.category, 'Holiday');
      expect(document.filePaths, ['/path/to/file.pdf']);
      expect(
          document.renewalDate?.getDateTimeInUtc(), DateTime.utc(2025, 12, 31));
      expect(document.notes, 'Test notes');
      expect(document.createdAt.getDateTimeInUtc(), DateTime.utc(2025, 1, 1));
    });

    test('Document should handle null optional fields in map', () {
      final map = {
        'id': 'doc-1',
        'userId': 'test-user',
        'title': 'Test',
        'category': 'Other',
        'filePaths': <String>[],
        'renewalDate': null,
        'notes': null,
        'createdAt': '2025-01-01T00:00:00.000',
        'lastModified': '2025-01-01T00:00:00.000',
        'version': 1,
        'syncState': 'notSynced',
      };

      final document = DocumentExtensions.fromMap(map);

      expect(document.filePaths, isEmpty);
      expect(document.renewalDate, isNull);
      expect(document.notes, isNull);
    });
  });

  group('Cloud Sync Extended Fields Tests', () {
    test('Document should be created with cloud sync fields', () {
      final createdAt = amplify_core.TemporalDateTime.now();
      final lastModified = amplify_core.TemporalDateTime.now();

      final document = Document(
        userId: 'user123',
        title: 'Test Insurance',
        category: 'Home Insurance',
        filePaths: [],
        createdAt: createdAt,
        lastModified: lastModified,
        version: 5,
        syncState: SyncState.synced.toJson(),
        conflictId: 'conflict123',
      );

      expect(document.userId, 'user123');
      expect(document.version, 5);
      expect(document.syncState, SyncState.synced.toJson());
      expect(document.conflictId, 'conflict123');
      expect(document.lastModified, isNotNull);
    });

    test('Document should have default cloud sync values', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      expect(document.userId, 'test-user');
      expect(document.version, 1);
      expect(document.syncState, SyncState.notSynced.toJson());
      expect(document.conflictId, isNull);
      expect(document.lastModified, isNotNull);
    });

    test('Document should serialize cloud sync fields to map', () {
      final lastModified =
          amplify_core.TemporalDateTime(DateTime(2025, 6, 15, 10, 30));
      final createdAt = amplify_core.TemporalDateTime.now();

      final document = Document(
        id: 'doc-1',
        userId: 'user456',
        title: 'Test Doc',
        category: 'Mortgage',
        filePaths: [],
        createdAt: createdAt,
        lastModified: lastModified,
        version: 3,
        syncState: SyncState.pending.toJson(),
        conflictId: 'conflict456',
      );

      final map = document.toMap();

      expect(map['userId'], 'user456');
      expect(map['lastModified'], lastModified);
      expect(map['version'], 3);
      expect(map['syncState'], SyncState.pending.toJson());
      expect(map['conflictId'], 'conflict456');
    });

    test('Document should deserialize cloud sync fields from map', () {
      final map = {
        'id': 'doc-1',
        'userId': 'user789',
        'title': 'Holiday Booking',
        'category': 'Holiday',
        'filePaths': ['/path/to/file.pdf'],
        'renewalDate': '2025-12-31T00:00:00.000',
        'notes': 'Test notes',
        'createdAt': '2025-01-01T00:00:00.000',
        'lastModified': '2025-06-15T10:30:00.000',
        'version': 7,
        'syncState': 'synced',
        'conflictId': 'conflict789',
      };

      final document = DocumentExtensions.fromMap(map);

      expect(document.userId, 'user789');
      expect(document.lastModified.getDateTimeInUtc(),
          DateTime.utc(2025, 6, 15, 9, 30));
      expect(document.version, 7);
      expect(document.syncState, 'synced');
      expect(document.conflictId, 'conflict789');
    });

    test(
        'Document should handle missing cloud sync fields in map with defaults',
        () {
      final map = {
        'id': 'doc-1',
        'title': 'Test',
        'category': 'Other',
        'createdAt': '2025-01-01T00:00:00.000',
      };

      final document = DocumentExtensions.fromMap(map);

      expect(document.userId, 'unknown');
      expect(document.lastModified, isNotNull);
      expect(document.version, 1);
      expect(document.syncState, SyncState.notSynced.toJson());
      expect(document.conflictId, isNull);
    });

    test('Document copyWith should increase version and update lastModified',
        () {
      final originalTime = amplify_core.TemporalDateTime(DateTime(2025, 1, 1));
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: originalTime,
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      final updated = document.copyWith(
        version: 2,
        lastModified: amplify_core.TemporalDateTime.now(),
      );

      expect(updated.version, 2);
      expect(
          updated.lastModified
              .getDateTimeInUtc()
              .isAfter(originalTime.getDateTimeInUtc()),
          true);
      expect(updated.title, document.title);
      expect(updated.category, document.category);
    });

    test('Document copyWith should work multiple times', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      final v2 = document.copyWith(version: 2);
      final v3 = v2.copyWith(version: 3);
      final v4 = v3.copyWith(version: 4);

      expect(v2.version, 2);
      expect(v3.version, 3);
      expect(v4.version, 4);
    });

    test('Document copyWith should update cloud sync fields', () {
      final document = Document(
        userId: 'user1',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      final updated = document.copyWith(
        userId: 'user2',
        version: 5,
        syncState: SyncState.synced.toJson(),
        conflictId: 'conflict123',
      );

      expect(updated.userId, 'user2');
      expect(updated.version, 5);
      expect(updated.syncState, SyncState.synced.toJson());
      expect(updated.conflictId, 'conflict123');
      expect(updated.title, document.title);
    });
  });

  group('SyncState Transitions Tests', () {
    test('Document should transition from notSynced to pending', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.notSynced.toJson(),
      );

      final updated = document.copyWith(syncState: SyncState.pending.toJson());

      expect(document.syncState, SyncState.notSynced.toJson());
      expect(updated.syncState, SyncState.pending.toJson());
    });

    test('Document should transition from pending to syncing', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.pending.toJson(),
      );

      final updated = document.copyWith(syncState: SyncState.syncing.toJson());

      expect(updated.syncState, SyncState.syncing.toJson());
    });

    test('Document should transition from syncing to synced', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.syncing.toJson(),
      );

      final updated = document.copyWith(syncState: SyncState.synced.toJson());

      expect(updated.syncState, SyncState.synced.toJson());
    });

    test('Document should transition to conflict state', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.syncing.toJson(),
      );

      final updated = document.copyWith(
        syncState: SyncState.conflict.toJson(),
        conflictId: 'conflict123',
      );

      expect(updated.syncState, SyncState.conflict.toJson());
      expect(updated.conflictId, 'conflict123');
    });

    test('Document should transition to error state', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.syncing.toJson(),
      );

      final updated = document.copyWith(syncState: SyncState.error.toJson());

      expect(updated.syncState, SyncState.error.toJson());
    });

    test('Document should transition from error back to pending', () {
      final document = Document(
        userId: 'test-user',
        title: 'Test Doc',
        category: 'Other',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: SyncState.error.toJson(),
      );

      final updated = document.copyWith(syncState: SyncState.pending.toJson());

      expect(updated.syncState, SyncState.pending.toJson());
    });
  });
}
