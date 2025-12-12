import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/document.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('Document Model Tests', () {
    test('Document should be created with required fields', () {
      final document = Document(
        title: 'Test Insurance',
        category: 'Home Insurance',
      );

      expect(document.title, 'Test Insurance');
      expect(document.category, 'Home Insurance');
      expect(document.id, isNull);
      expect(document.filePath, isNull);
      expect(document.renewalDate, isNull);
      expect(document.notes, isNull);
      expect(document.createdAt, isNotNull);
    });

    test('Document should be created with all fields', () {
      final renewalDate = DateTime(2025, 12, 31);
      final createdAt = DateTime(2025, 1, 1);

      final document = Document(
        id: 1,
        title: 'Car Insurance',
        category: 'Car Insurance',
        filePath: '/path/to/file.pdf',
        renewalDate: renewalDate,
        notes: 'Test notes',
        createdAt: createdAt,
      );

      expect(document.id, 1);
      expect(document.title, 'Car Insurance');
      expect(document.category, 'Car Insurance');
      expect(document.filePath, '/path/to/file.pdf');
      expect(document.renewalDate, renewalDate);
      expect(document.notes, 'Test notes');
      expect(document.createdAt, createdAt);
    });

    test('Document should convert to map correctly', () {
      final renewalDate = DateTime(2025, 12, 31);
      final document = Document(
        id: 1,
        title: 'Test Doc',
        category: 'Mortgage',
        renewalDate: renewalDate,
      );

      final map = document.toMap();

      expect(map['id'], 1);
      expect(map['title'], 'Test Doc');
      expect(map['category'], 'Mortgage');
      expect(map['renewalDate'], renewalDate.toIso8601String());
      expect(map['createdAt'], isNotNull);
    });

    test('Document should be created from map correctly', () {
      final map = {
        'id': 1,
        'title': 'Holiday Booking',
        'category': 'Holiday',
        'filePath': '/path/to/file.pdf',
        'renewalDate': '2025-12-31T00:00:00.000',
        'notes': 'Test notes',
        'createdAt': '2025-01-01T00:00:00.000',
      };

      final document = Document.fromMap(map);

      expect(document.id, 1);
      expect(document.title, 'Holiday Booking');
      expect(document.category, 'Holiday');
      expect(document.filePath, '/path/to/file.pdf');
      expect(document.renewalDate, DateTime(2025, 12, 31));
      expect(document.notes, 'Test notes');
      expect(document.createdAt, DateTime(2025, 1, 1));
    });

    test('Document should handle null optional fields in map', () {
      final map = {
        'id': 1,
        'title': 'Test',
        'category': 'Other',
        'filePath': null,
        'renewalDate': null,
        'notes': null,
        'createdAt': '2025-01-01T00:00:00.000',
      };

      final document = Document.fromMap(map);

      expect(document.filePath, isNull);
      expect(document.renewalDate, isNull);
      expect(document.notes, isNull);
    });
  });

  group('Cloud Sync Extended Fields Tests', () {
    test('Document should be created with cloud sync fields', () {
      final document = Document(
        userId: 'user123',
        title: 'Test Insurance',
        category: 'Home Insurance',
        version: 5,
        syncState: SyncState.synced,
        conflictId: 'conflict123',
      );

      expect(document.userId, 'user123');
      expect(document.version, 5);
      expect(document.syncState, SyncState.synced);
      expect(document.conflictId, 'conflict123');
      expect(document.lastModified, isNotNull);
    });

    test('Document should have default cloud sync values', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
      );

      expect(document.userId, isNull);
      expect(document.version, 1);
      expect(document.syncState, SyncState.notSynced);
      expect(document.conflictId, isNull);
      expect(document.lastModified, isNotNull);
    });

    test('Document should serialize cloud sync fields to map', () {
      final lastModified = DateTime(2025, 6, 15, 10, 30);
      final document = Document(
        id: 1,
        userId: 'user456',
        title: 'Test Doc',
        category: 'Mortgage',
        lastModified: lastModified,
        version: 3,
        syncState: SyncState.pending,
        conflictId: 'conflict456',
      );

      final map = document.toMap();

      expect(map['userId'], 'user456');
      expect(map['lastModified'], lastModified.toIso8601String());
      expect(map['version'], 3);
      expect(map['syncState'], 'pending');
      expect(map['conflictId'], 'conflict456');
    });

    test('Document should deserialize cloud sync fields from map', () {
      final map = {
        'id': 1,
        'userId': 'user789',
        'title': 'Holiday Booking',
        'category': 'Holiday',
        'filePath': '/path/to/file.pdf',
        'renewalDate': '2025-12-31T00:00:00.000',
        'notes': 'Test notes',
        'createdAt': '2025-01-01T00:00:00.000',
        'lastModified': '2025-06-15T10:30:00.000',
        'version': 7,
        'syncState': 'synced',
        'conflictId': 'conflict789',
      };

      final document = Document.fromMap(map);

      expect(document.userId, 'user789');
      expect(document.lastModified, DateTime(2025, 6, 15, 10, 30));
      expect(document.version, 7);
      expect(document.syncState, SyncState.synced);
      expect(document.conflictId, 'conflict789');
    });

    test(
        'Document should handle missing cloud sync fields in map with defaults',
        () {
      final map = {
        'id': 1,
        'title': 'Test',
        'category': 'Other',
        'createdAt': '2025-01-01T00:00:00.000',
      };

      final document = Document.fromMap(map);

      expect(document.userId, isNull);
      expect(document.lastModified, isNotNull);
      expect(document.version, 1);
      expect(document.syncState, SyncState.notSynced);
      expect(document.conflictId, isNull);
    });

    test(
        'Document incrementVersion should increase version and update lastModified',
        () {
      final originalTime = DateTime(2025, 1, 1);
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        version: 1,
        lastModified: originalTime,
      );

      final updated = document.incrementVersion();

      expect(updated.version, 2);
      expect(updated.lastModified.isAfter(originalTime), true);
      expect(updated.title, document.title);
      expect(updated.category, document.category);
    });

    test('Document incrementVersion should work multiple times', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        version: 1,
      );

      final v2 = document.incrementVersion();
      final v3 = v2.incrementVersion();
      final v4 = v3.incrementVersion();

      expect(v2.version, 2);
      expect(v3.version, 3);
      expect(v4.version, 4);
    });

    test('Document copyWith should update cloud sync fields', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        userId: 'user1',
        version: 1,
        syncState: SyncState.notSynced,
      );

      final updated = document.copyWith(
        userId: 'user2',
        version: 5,
        syncState: SyncState.synced,
        conflictId: 'conflict123',
      );

      expect(updated.userId, 'user2');
      expect(updated.version, 5);
      expect(updated.syncState, SyncState.synced);
      expect(updated.conflictId, 'conflict123');
      expect(updated.title, document.title);
    });
  });

  group('SyncState Transitions Tests', () {
    test('Document should transition from notSynced to pending', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        syncState: SyncState.notSynced,
      );

      final updated = document.copyWith(syncState: SyncState.pending);

      expect(document.syncState, SyncState.notSynced);
      expect(updated.syncState, SyncState.pending);
    });

    test('Document should transition from pending to syncing', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        syncState: SyncState.pending,
      );

      final updated = document.copyWith(syncState: SyncState.syncing);

      expect(updated.syncState, SyncState.syncing);
    });

    test('Document should transition from syncing to synced', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        syncState: SyncState.syncing,
      );

      final updated = document.copyWith(syncState: SyncState.synced);

      expect(updated.syncState, SyncState.synced);
    });

    test('Document should transition to conflict state', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        syncState: SyncState.syncing,
      );

      final updated = document.copyWith(
        syncState: SyncState.conflict,
        conflictId: 'conflict123',
      );

      expect(updated.syncState, SyncState.conflict);
      expect(updated.conflictId, 'conflict123');
    });

    test('Document should transition to error state', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        syncState: SyncState.syncing,
      );

      final updated = document.copyWith(syncState: SyncState.error);

      expect(updated.syncState, SyncState.error);
    });

    test('Document should transition from error back to pending', () {
      final document = Document(
        title: 'Test Doc',
        category: 'Other',
        syncState: SyncState.error,
      );

      final updated = document.copyWith(syncState: SyncState.pending);

      expect(updated.syncState, SyncState.pending);
    });
  });
}
