import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/models/file_attachment.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('Document', () {
    test('create factory generates valid document with UUID', () {
      final doc = Document.create(
        title: 'Test Document',
        category: DocumentCategory.expenses,
        date: DateTime(2024, 12, 31),
        notes: 'Test Notes',
      );

      expect(doc.syncId, isNotEmpty);
      expect(doc.title, equals('Test Document'));
      expect(doc.category, equals(DocumentCategory.expenses));
      expect(doc.date, equals(DateTime(2024, 12, 31)));
      expect(doc.notes, equals('Test Notes'));
      expect(doc.syncState, equals(SyncState.pendingUpload));
      expect(doc.files, isEmpty);
      expect(doc.createdAt, isNotNull);
      expect(doc.updatedAt, isNotNull);
    });

    test('create factory with minimal fields', () {
      final doc = Document.create(
        title: 'Minimal Doc',
        category: DocumentCategory.other,
      );

      expect(doc.syncId, isNotEmpty);
      expect(doc.title, equals('Minimal Doc'));
      expect(doc.category, equals(DocumentCategory.other));
      expect(doc.date, isNull);
      expect(doc.notes, isNull);
      expect(doc.syncState, equals(SyncState.pendingUpload));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = Document.create(
        title: 'Original',
        category: DocumentCategory.carInsurance,
      );
      final updated = original.copyWith(
        title: 'Updated',
        category: DocumentCategory.homeInsurance,
        date: DateTime(2025, 6, 15),
        syncState: SyncState.synced,
      );

      expect(updated.title, equals('Updated'));
      expect(updated.category, equals(DocumentCategory.homeInsurance));
      expect(updated.date, equals(DateTime(2025, 6, 15)));
      expect(updated.syncState, equals(SyncState.synced));
      expect(updated.syncId, equals(original.syncId));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test('copyWith can clear date field', () {
      final original = Document.create(
        title: 'Test',
        category: DocumentCategory.holiday,
        date: DateTime(2024, 12, 31),
      );
      final updated = original.copyWith(clearDate: true);

      expect(updated.date, isNull);
    });

    test('toJson and fromJson round trip', () {
      final original = Document.create(
        title: 'Test',
        category: DocumentCategory.carInsurance,
        date: DateTime(2024, 12, 31),
        notes: 'Notes',
      );

      final json = original.toJson();
      final restored = Document.fromJson(json);

      expect(restored.syncId, equals(original.syncId));
      expect(restored.title, equals(original.title));
      expect(restored.category, equals(original.category));
      expect(restored.date, equals(original.date));
      expect(restored.notes, equals(original.notes));
      expect(restored.syncState, equals(original.syncState));
    });

    test('toDatabase and fromDatabase round trip', () {
      final original = Document.create(
        title: 'Test',
        category: DocumentCategory.homeInsurance,
        date: DateTime(2025, 3, 15),
        notes: 'Notes',
      );

      final dbMap = original.toDatabase();
      final restored = Document.fromDatabase(dbMap);

      expect(restored.syncId, equals(original.syncId));
      expect(restored.title, equals(original.title));
      expect(restored.category, equals(original.category));
      expect(restored.date, equals(original.date));
      expect(restored.notes, equals(original.notes));
      expect(restored.syncState, equals(original.syncState));
      expect(restored.files, isEmpty); // Files not included in database map
    });

    test('validate throws on empty syncId', () {
      final doc = Document(
        syncId: '',
        title: 'Test',
        category: DocumentCategory.other,
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
        category: DocumentCategory.other,
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
        category: DocumentCategory.other,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.pendingUpload,
      );

      expect(() => doc.validate(), throwsArgumentError);
    });

    test('validate succeeds with valid document', () {
      final doc = Document.create(
        title: 'Valid Document',
        category: DocumentCategory.expenses,
      );

      expect(() => doc.validate(), returnsNormally);
    });

    test('equality operator works correctly', () {
      final doc1 = Document.create(
        title: 'Test',
        category: DocumentCategory.other,
      );
      final doc2 = doc1.copyWith();
      final doc3 = Document.create(
        title: 'Different',
        category: DocumentCategory.holiday,
      );

      expect(doc1, equals(doc2));
      expect(doc1, isNot(equals(doc3)));
    });

    test('hashCode is consistent', () {
      final doc1 = Document.create(
        title: 'Test',
        category: DocumentCategory.other,
      );
      final doc2 = doc1.copyWith();

      expect(doc1.hashCode, equals(doc2.hashCode));
    });

    test('toString provides useful information', () {
      final doc = Document.create(
        title: 'Test Document',
        category: DocumentCategory.carInsurance,
      );
      final str = doc.toString();

      expect(str, contains('Document'));
      expect(str, contains(doc.syncId));
      expect(str, contains('Test Document'));
      expect(str, contains('Car Insurance'));
      expect(str, contains('pendingUpload'));
    });

    test('handles null notes correctly', () {
      final doc = Document.create(
        title: 'Test',
        category: DocumentCategory.other,
      );
      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.notes, isNull);
    });

    test('handles null date correctly', () {
      final doc = Document.create(
        title: 'Test',
        category: DocumentCategory.other,
      );
      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.date, isNull);
    });

    test('preserves file attachments in JSON round trip', () {
      final file = FileAttachment(
        fileName: 'test.pdf',
        localPath: '/path/to/file',
        s3Key: 's3://bucket/key',
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      final doc = Document.create(
        title: 'Test',
        category: DocumentCategory.expenses,
      ).copyWith(files: [file]);
      final json = doc.toJson();
      final restored = Document.fromJson(json);

      expect(restored.files.length, equals(1));
      expect(restored.files.first.fileName, equals('test.pdf'));
    });

    test('category date labels are correct', () {
      expect(DocumentCategory.carInsurance.dateLabel, equals('Renewal Date'));
      expect(DocumentCategory.homeInsurance.dateLabel, equals('Renewal Date'));
      expect(DocumentCategory.holiday.dateLabel, equals('Payment Due'));
      expect(DocumentCategory.expenses.dateLabel, equals('Date'));
      expect(DocumentCategory.other.dateLabel, equals('Date'));
    });

    test('category display names are correct', () {
      expect(
          DocumentCategory.carInsurance.displayName, equals('Car Insurance'));
      expect(
          DocumentCategory.homeInsurance.displayName, equals('Home Insurance'));
      expect(DocumentCategory.holiday.displayName, equals('Holiday'));
      expect(DocumentCategory.expenses.displayName, equals('Expenses'));
      expect(DocumentCategory.other.displayName, equals('Other'));
    });
  });
}
