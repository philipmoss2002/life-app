import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/FileAttachment.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/models/model_extensions.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

void main() {
  group('FileAttachment Model Tests', () {
    test('FileAttachment should be created with required fields', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'document.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.notSynced.toJson(),
      );

      expect(attachment.filePath, '/path/to/file.pdf');
      expect(attachment.fileName, 'document.pdf');
      expect(attachment.id, isNotNull);
      expect(attachment.label, isNull);
      expect(attachment.addedAt, isNotNull);
      expect(attachment.fileSize, 1024);
      expect(attachment.syncState, SyncState.notSynced.toJson());
    });

    test('FileAttachment should be created with all fields', () {
      final addedAt = amplify_core.TemporalDateTime(DateTime(2025, 1, 1));

      final attachment = FileAttachment(
        id: 'attachment-1',
        filePath: '/path/to/file.pdf',
        fileName: 'insurance.pdf',
        label: 'Policy Document',
        fileSize: 1024000,
        s3Key: 's3://bucket/key',
        addedAt: addedAt,
        syncState: SyncState.synced.toJson(),
      );

      expect(attachment.id, 'attachment-1');
      expect(attachment.filePath, '/path/to/file.pdf');
      expect(attachment.fileName, 'insurance.pdf');
      expect(attachment.label, 'Policy Document');
      expect(attachment.fileSize, 1024000);
      expect(attachment.s3Key, 's3://bucket/key');
      expect(attachment.addedAt, addedAt);
      expect(attachment.syncState, SyncState.synced.toJson());
    });

    test('FileAttachment should convert to map correctly', () {
      final attachment = FileAttachment(
        id: 'attachment-2',
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        label: 'Test Label',
        fileSize: 2048,
        s3Key: 's3://test/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.pending.toJson(),
      );

      final map = attachment.toMap();

      expect(map['id'], 'attachment-2');
      expect(map['filePath'], '/path/to/file.pdf');
      expect(map['fileName'], 'test.pdf');
      expect(map['label'], 'Test Label');
      expect(map['fileSize'], 2048);
      expect(map['s3Key'], 's3://test/key');
      expect(map['addedAt'], isNotNull);
      expect(map['syncState'], 'pending');
    });

    test('FileAttachment should be created from map correctly', () {
      final map = {
        'id': 'attachment-3',
        'filePath': '/path/to/file.pdf',
        'fileName': 'document.pdf',
        'label': 'Important',
        'fileSize': 4096,
        's3Key': 's3://bucket/file',
        'addedAt': '2025-01-01T00:00:00.000',
        'syncState': 'synced',
      };

      final attachment = FileAttachmentExtensions.fromMap(map);

      expect(attachment.id, 'attachment-3');
      expect(attachment.filePath, '/path/to/file.pdf');
      expect(attachment.fileName, 'document.pdf');
      expect(attachment.label, 'Important');
      expect(attachment.fileSize, 4096);
      expect(attachment.s3Key, 's3://bucket/file');
      expect(attachment.addedDateTime, DateTime.utc(2025, 1, 1));
      expect(attachment.syncState, 'synced');
    });

    test('FileAttachment should handle null optional fields in map', () {
      final map = {
        'id': 'attachment-4',
        'filePath': '/path/to/file.pdf',
        'fileName': 'test.pdf',
        'label': null,
        's3Key': '',
        'addedAt': '2025-01-01T00:00:00.000',
      };

      final attachment = FileAttachmentExtensions.fromMap(map);

      expect(attachment.label, isNull);
      expect(attachment.s3Key, '');
      expect(attachment.fileSize, 0);
      expect(attachment.syncState, SyncState.notSynced.toJson());
    });

    test('FileAttachment should return label if present', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'document.pdf',
        label: 'My Label',
        fileSize: 1024,
        s3Key: 's3://bucket/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.notSynced.toJson(),
      );

      expect(attachment.label, 'My Label');
    });

    test('FileAttachment should return fileName when label is null', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'document.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.notSynced.toJson(),
      );

      expect(attachment.fileName, 'document.pdf');
      expect(attachment.label, isNull);
    });

    test('FileAttachment copyWith should update fields correctly', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        s3Key: 's3://old/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.notSynced.toJson(),
      );

      final updated = attachment.copyWith(
        label: 'New Label',
        fileSize: 2048,
        s3Key: 's3://new/key',
        syncState: SyncState.synced.toJson(),
      );

      expect(updated.label, 'New Label');
      expect(updated.fileSize, 2048);
      expect(updated.s3Key, 's3://new/key');
      expect(updated.syncState, SyncState.synced.toJson());
      expect(updated.filePath, attachment.filePath);
      expect(updated.fileName, attachment.fileName);
    });
  });

  group('FileAttachment Sync State Tests', () {
    test('FileAttachment should transition from notSynced to pending', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.notSynced.toJson(),
      );

      final updated =
          attachment.copyWith(syncState: SyncState.pending.toJson());

      expect(attachment.syncState, SyncState.notSynced.toJson());
      expect(updated.syncState, SyncState.pending.toJson());
    });

    test('FileAttachment should transition from pending to syncing', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.pending.toJson(),
      );

      final updated =
          attachment.copyWith(syncState: SyncState.syncing.toJson());

      expect(updated.syncState, SyncState.syncing.toJson());
    });

    test('FileAttachment should transition from syncing to synced with s3Key',
        () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/temp',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.syncing.toJson(),
      );

      final updated = attachment.copyWith(
        syncState: SyncState.synced.toJson(),
        s3Key: 's3://bucket/uploaded-file',
      );

      expect(updated.syncState, SyncState.synced.toJson());
      expect(updated.s3Key, 's3://bucket/uploaded-file');
    });

    test('FileAttachment should transition to error state', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/key',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.syncing.toJson(),
      );

      final updated = attachment.copyWith(syncState: SyncState.error.toJson());

      expect(updated.syncState, SyncState.error.toJson());
    });

    test('FileAttachment should handle s3Key updates', () {
      final attachment = FileAttachment(
        filePath: '/path/to/file.pdf',
        fileName: 'test.pdf',
        fileSize: 1024,
        s3Key: 's3://bucket/file',
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: SyncState.synced.toJson(),
      );

      final updated = attachment.copyWith(
        s3Key: 's3://bucket/new-file',
      );

      expect(updated.s3Key, 's3://bucket/new-file');
      expect(updated.syncState, SyncState.synced.toJson());
    });
  });
}
