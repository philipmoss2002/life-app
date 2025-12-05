import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/file_attachment.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('FileAttachment Model Tests', () {
    test('FileAttachment should be created with required fields', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'document.pdf',
      );

      expect(attachment.filePath, '/path/to/file.pdf');
      expect(attachment.fileName, 'document.pdf');
      expect(attachment.id, isNull);
      expect(attachment.label, isNull);
      expect(attachment.addedAt, isNotNull);
      expect(attachment.fileSize, 0);
      expect(attachment.syncState, SyncState.notSynced);
    });

    test('FileAttachment should be created with all fields', () {
      final addedAt = DateTime(2025, 1, 1);

      final attachment = FileAttachment(
        id: 1,
        documentId: 'doc123',
        filePath: '/path/to/file.pdf',
        fileName: 'insurance.pdf',
        label: 'Policy Document',
        fileSize: 1024000,
        s3Key: 's3://bucket/key',
        localPath: '/cache/file.pdf',
        addedAt: addedAt,
        syncState: SyncState.synced,
      );

      expect(attachment.id, 1);
      expect(attachment.documentId, 'doc123');
      expect(attachment.filePath, '/path/to/file.pdf');
      expect(attachment.fileName, 'insurance.pdf');
      expect(attachment.label, 'Policy Document');
      expect(attachment.fileSize, 1024000);
      expect(attachment.s3Key, 's3://bucket/key');
      expect(attachment.localPath, '/cache/file.pdf');
      expect(attachment.addedAt, addedAt);
      expect(attachment.syncState, SyncState.synced);
    });

    test('FileAttachment should convert to map correctly', () {
      final attachment = FileAttachment(
        id: 1,
        documentId: 'doc456',
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        label: 'Test Label',
        fileSize: 2048,
        s3Key: 's3://test/key',
        localPath: '/cache/test.pdf',
        syncState: SyncState.pending,
      );

      final map = attachment.toMap();

      expect(map['id'], 1);
      expect(map['documentId'], 'doc456');
      expect(map['filePath'], '/path/to/file.pdf');
      expect(map['fileName'], 'test.pdf');
      expect(map['label'], 'Test Label');
      expect(map['fileSize'], 2048);
      expect(map['s3Key'], 's3://test/key');
      expect(map['localPath'], '/cache/test.pdf');
      expect(map['addedAt'], isNotNull);
      expect(map['syncState'], 'pending');
    });

    test('FileAttachment should be created from map correctly', () {
      final map = {
        'id': 1,
        'documentId': 'doc789',
        'filePath': '/path/to/file.pdf',
        'fileName': 'document.pdf',
        'label': 'Important',
        'fileSize': 4096,
        's3Key': 's3://bucket/file',
        'localPath': '/cache/doc.pdf',
        'addedAt': '2025-01-01T00:00:00.000',
        'syncState': 'synced',
      };

      final attachment = FileAttachment.fromMap(map);

      expect(attachment.id, 1);
      expect(attachment.documentId, 'doc789');
      expect(attachment.filePath, '/path/to/file.pdf');
      expect(attachment.fileName, 'document.pdf');
      expect(attachment.label, 'Important');
      expect(attachment.fileSize, 4096);
      expect(attachment.s3Key, 's3://bucket/file');
      expect(attachment.localPath, '/cache/doc.pdf');
      expect(attachment.addedAt, DateTime(2025, 1, 1));
      expect(attachment.syncState, SyncState.synced);
    });

    test('FileAttachment should handle null optional fields in map', () {
      final map = {
        'id': 1,
        'filePath': '/path/to/file.pdf',
        'fileName': 'test.pdf',
        'label': null,
        'documentId': null,
        's3Key': null,
        'localPath': null,
        'addedAt': '2025-01-01T00:00:00.000',
      };

      final attachment = FileAttachment.fromMap(map);

      expect(attachment.label, isNull);
      expect(attachment.documentId, isNull);
      expect(attachment.s3Key, isNull);
      expect(attachment.localPath, isNull);
      expect(attachment.fileSize, 0);
      expect(attachment.syncState, SyncState.notSynced);
    });

    test('FileAttachment displayName should return label if present', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'document.pdf',
        label: 'My Label',
      );

      expect(attachment.displayName, 'My Label');
    });

    test('FileAttachment displayName should return fileName if label is null',
        () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'document.pdf',
      );

      expect(attachment.displayName, 'document.pdf');
    });

    test('FileAttachment copyWith should update fields correctly', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        syncState: SyncState.notSynced,
      );

      final updated = attachment.copyWith(
        documentId: 'doc123',
        label: 'New Label',
        fileSize: 2048,
        s3Key: 's3://new/key',
        localPath: '/new/cache/path',
        syncState: SyncState.synced,
      );

      expect(updated.documentId, 'doc123');
      expect(updated.label, 'New Label');
      expect(updated.fileSize, 2048);
      expect(updated.s3Key, 's3://new/key');
      expect(updated.localPath, '/new/cache/path');
      expect(updated.syncState, SyncState.synced);
      expect(updated.filePath, attachment.filePath);
      expect(updated.fileName, attachment.fileName);
    });
  });

  group('FileAttachment Sync State Tests', () {
    test('FileAttachment should transition from notSynced to pending', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        syncState: SyncState.notSynced,
      );

      final updated = attachment.copyWith(syncState: SyncState.pending);

      expect(attachment.syncState, SyncState.notSynced);
      expect(updated.syncState, SyncState.pending);
    });

    test('FileAttachment should transition from pending to syncing', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        syncState: SyncState.pending,
      );

      final updated = attachment.copyWith(syncState: SyncState.syncing);

      expect(updated.syncState, SyncState.syncing);
    });

    test('FileAttachment should transition from syncing to synced with s3Key',
        () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        syncState: SyncState.syncing,
      );

      final updated = attachment.copyWith(
        syncState: SyncState.synced,
        s3Key: 's3://bucket/uploaded-file',
      );

      expect(updated.syncState, SyncState.synced);
      expect(updated.s3Key, 's3://bucket/uploaded-file');
    });

    test('FileAttachment should transition to error state', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        syncState: SyncState.syncing,
      );

      final updated = attachment.copyWith(syncState: SyncState.error);

      expect(updated.syncState, SyncState.error);
    });

    test('FileAttachment should update localPath when downloaded', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        s3Key: 's3://bucket/file',
        syncState: SyncState.synced,
      );

      final updated = attachment.copyWith(
        localPath: '/cache/downloaded-file.pdf',
      );

      expect(updated.localPath, '/cache/downloaded-file.pdf');
      expect(updated.s3Key, 's3://bucket/file');
    });
  });
}
