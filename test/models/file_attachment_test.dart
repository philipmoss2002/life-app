import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/file_attachment.dart';

void main() {
  group('FileAttachment', () {
    test('creates file attachment with all fields', () {
      final now = DateTime.now();
      final file = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        s3Key: 's3://bucket/key',
        fileSize: 1024,
        addedAt: now,
      );

      expect(file.fileName, equals('test.pdf'));
      expect(file.localPath, equals('/path/to/file'));
      expect(file.s3Key, equals('s3://bucket/key'));
      expect(file.fileSize, equals(1024));
      expect(file.addedAt, equals(now));
    });

    test('creates file attachment with minimal fields', () {
      final now = DateTime.now();
      final file = FileAttachment(
        fileName: 'test.pdf',
        addedAt: now,
      );

      expect(file.fileName, equals('test.pdf'));
      expect(file.localPath, isNull);
      expect(file.s3Key, isNull);
      expect(file.fileSize, isNull);
      expect(file.addedAt, equals(now));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = FileAttachment(
        fileName: 'original.pdf',
        addedAt: DateTime.now(),
      );

      final updated = original.copyWith(
        fileName: 'updated.pdf',
        s3Key: 's3://new/key',
      );

      expect(updated.fileName, equals('updated.pdf'));
      expect(updated.s3Key, equals('s3://new/key'));
      expect(updated.addedAt, equals(original.addedAt));
    });

    test('toJson and fromJson round trip', () {
      final original = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        s3Key: 's3://bucket/key',
        fileSize: 2048,
        addedAt: DateTime.now(),
      );

      final json = original.toJson();
      final restored = FileAttachment.fromJson(json);

      expect(restored.fileName, equals(original.fileName));
      expect(restored.localPath, equals(original.localPath));
      expect(restored.s3Key, equals(original.s3Key));
      expect(restored.fileSize, equals(original.fileSize));
      expect(
        restored.addedAt.millisecondsSinceEpoch,
        equals(original.addedAt.millisecondsSinceEpoch),
      );
    });

    test('toDatabase and fromDatabase round trip', () {
      final original = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        s3Key: 's3://bucket/key',
        fileSize: 2048,
        addedAt: DateTime.now(),
      );

      final dbMap = original.toDatabase('test-sync-id');
      final restored = FileAttachment.fromDatabase(dbMap);

      expect(restored.fileName, equals(original.fileName));
      expect(restored.localPath, equals(original.localPath));
      expect(restored.s3Key, equals(original.s3Key));
      expect(restored.fileSize, equals(original.fileSize));
      expect(
        restored.addedAt.millisecondsSinceEpoch,
        equals(original.addedAt.millisecondsSinceEpoch),
      );
    });

    test('toDatabase includes syncId', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        addedAt: DateTime.now(),
      );

      final dbMap = file.toDatabase('my-sync-id');

      expect(dbMap['sync_id'], equals('my-sync-id'));
      expect(dbMap['file_name'], equals('test.pdf'));
    });

    test('validate throws on empty fileName', () {
      final file = FileAttachment(
        fileName: '',
        addedAt: DateTime.now(),
      );

      expect(() => file.validate(), throwsArgumentError);
    });

    test('validate succeeds with valid file', () {
      final file = FileAttachment(
        fileName: 'valid.pdf',
        addedAt: DateTime.now(),
      );

      expect(() => file.validate(), returnsNormally);
    });

    test('isDownloaded returns true when localPath is set', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        addedAt: DateTime.now(),
      );

      expect(file.isDownloaded, isTrue);
    });

    test('isDownloaded returns false when localPath is null', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        addedAt: DateTime.now(),
      );

      expect(file.isDownloaded, isFalse);
    });

    test('isUploaded returns true when s3Key is set', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        s3Key: 's3://bucket/key',
        addedAt: DateTime.now(),
      );

      expect(file.isUploaded, isTrue);
    });

    test('isUploaded returns false when s3Key is null', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        addedAt: DateTime.now(),
      );

      expect(file.isUploaded, isFalse);
    });

    test('equality operator works correctly', () {
      final now = DateTime.now();
      final file1 = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path',
        addedAt: now,
      );
      final file2 = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path',
        addedAt: now,
      );
      final file3 = FileAttachment(
        fileName: 'different.pdf',
        addedAt: now,
      );

      expect(file1, equals(file2));
      expect(file1, isNot(equals(file3)));
    });

    test('hashCode is consistent', () {
      final now = DateTime.now();
      final file1 = FileAttachment(
        fileName: 'test.pdf',
        addedAt: now,
      );
      final file2 = FileAttachment(
        fileName: 'test.pdf',
        addedAt: now,
      );

      expect(file1.hashCode, equals(file2.hashCode));
    });

    test('toString provides useful information', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        s3Key: 's3://bucket/key',
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      final str = file.toString();

      expect(str, contains('FileAttachment'));
      expect(str, contains('test.pdf'));
      expect(str, contains('/path/to/file'));
      expect(str, contains('s3://bucket/key'));
      expect(str, contains('1024'));
    });

    test('handles null optional fields in JSON round trip', () {
      final original = FileAttachment(
        fileName: 'test.pdf',
        addedAt: DateTime.now(),
      );

      final json = original.toJson();
      final restored = FileAttachment.fromJson(json);

      expect(restored.localPath, isNull);
      expect(restored.s3Key, isNull);
      expect(restored.fileSize, isNull);
    });
  });
}
