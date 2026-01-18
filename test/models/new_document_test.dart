import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/models/file_attachment.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('Document', () {
    test('create factory generates valid document with UUID', () {
      final doc = Document.create(
        title: 'Test Document',
        description: 'Test description',
        labels: ['label1', 'label2'],
      );

      expect(doc.syncId, isNotEmpty);
      expect(doc.title, equals('Test Document'));
      expect(doc.description, equals('Test description'));
      expect(doc.labels, equals(['label1', 'label2']));
      expect(doc.syncState, equals(SyncState.pendingUpload));
      expect(doc.files, isEmpty);
      expect(doc.createdAt, isNotNull);
      expect(doc.updatedAt, isNotNull);
    });

    test('create factory with minimal fields', () {
      final doc = Document.create(title: 'Minimal Doc');

      expect(doc.syncId, isNotEmpty);
      expect(doc.title, equals('Minimal Doc'));
      expect(doc.description, isNull);
      expect(doc.labels, isEmpty);
      expect(doc.syncState, equals(SyncState.pendingUpload));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Document.create(title: 'Original');
      final updated = original.copyWith(
        title: 'Updated',
        syncState: SyncState.synced,
      );

      expect(updated.title, equals('Updated'));
      expect(updated.syncState, equals(SyncState.synced));
      expect(updated.syncId, equals(original.syncId));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test('toJson and fromJson round trip', () {
      final original = Document.create(
        title: 'Test',
        description: 'Description',
        labels: ['a', 'b'],
      );

      final json = original.toJson();
      final restored = Document.fromJson(json);

      expect(restored.syncId, equals(original.syncId));
      expect(restored.title, equals(original.title));
      expect(restored.description, equals(original.description));
      expect(restored.labels, equals(original.labels));
      expect(restored.syncState, equals(original.syncState));
    });

    test('toDatabase and fromDatabase round trip', () {
      final original = Document.create(
        title: 'Test',
        description: 'Description',
        labels: ['a', 'b'],
      );

      final dbMap = original.toDatabase();
      final restored = Document.fromDatabase(dbMap);

      expect(restored.syncId, equals(original.syncId));
      expect(restored.title, equals(original.title));
      expect(restored.description, equals(original.description));
      expect(restored.labels, equals(original.labels));
      expect(restored.syncState, equals(original.syncState));
      expect(restored.files, isEmpty); // Files not included in database map
    });

    test('validate throws on empty syncId', () {
      final doc = Document(
        syncId: '',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.pendingUpload,
      );

      expect(() => doc.validate(), throwsArgumentError);
    });

    test('validate throws on empty title', () {
      final doc = Document(
        syncId: 'valid-uuid-format-here',
        title: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.pendingUpload,
      );

      expect(() => doc.validate(), throwsArgumentError);
    });

    test('validate throws on invalid UUID format', () {
      final doc = Document(
        syncId: 'not-a-valid-uuid',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.pendingUpload,
      );

      expect(() => doc.validate(), throwsArgumentError);
    });

    test('validate succeeds with valid document', () {
      final doc = Document.create(title: 'Valid Document');

      expect(() => doc.validate(), returnsNormally);
    });

    test('equality operator works correctly', () {
      final doc1 = Document.create(title: 'Test');
      final doc2 = doc1.copyWith();
      final doc3 = Document.create(title: 'Different');

      expect(doc1, equals(doc2));
      expect(doc1, isNot(equals(doc3)));
    });

    test('hashCode is consistent', () {
      final doc1 = Document.create(title: 'Test');
      final doc2 = doc1.copyWith();

      expect(doc1.hashCode, equals(doc2.hashCode));
    });

    test('toString provides useful information', () {
      final doc = Document.create(title: 'Test Document');
      final str = doc.toString();

      expect(str, contains('Document'));
      expect(str, contains(doc.syncId));
      expect(str, contains('Test Document'));
      expect(str, contains('pendingUpload'));
    });

    test('handles null description correctly', () {
      final doc = Document.create(title: 'Test');
      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.description, isNull);
    });

    test('handles empty labels list correctly', () {
      final doc = Document.create(title: 'Test', labels: []);
      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.labels, isEmpty);
    });

    test('preserves file attachments in JSON round trip', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        s3Key: 's3://bucket/key',
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      final doc = Document.create(title: 'Test').copyWith(files: [file]);
      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.files.length, equals(1));
      expect(restored.files.first.fileName, equals('test.pdf'));
    });
  });
}
