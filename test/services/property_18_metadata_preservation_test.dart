import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'dart:math';

/// **Feature: premium-subscription-gating, Property 18: Metadata preservation during sync**
/// **Validates: Requirements 10.3**
///
/// Property-based test to verify that when documents are synced to the cloud,
/// all original metadata (creation date, title, category, notes) is preserved
/// exactly as it was when the document was created locally.
///
/// This test verifies that the Document model correctly preserves metadata
/// through serialization and deserialization operations.
void main() {
  group('Property 18: Metadata preservation during sync', () {
    final random = Random();

    test('Document creation preserves all metadata fields', () async {
      // Property: For any document created, all metadata should be preserved

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Generate random metadata
        final title = 'Document $i ${_generateRandomString(20)}';
        final category = DocumentCategory
            .values[random.nextInt(DocumentCategory.values.length)];
        final date = random.nextBool()
            ? DateTime.now().subtract(Duration(days: random.nextInt(365)))
            : null;
        final notes =
            random.nextBool() ? 'Notes $i ${_generateRandomString(50)}' : null;

        // Create document
        final doc = Document.create(
          title: title,
          category: category,
          date: date,
          notes: notes,
        );

        // Verify all metadata is preserved
        expect(doc.title, equals(title));
        expect(doc.category, equals(category));
        expect(doc.date, equals(date));
        expect(doc.notes, equals(notes));
        expect(doc.syncState, equals(SyncState.pendingUpload));
      }
    });

    test('Document JSON serialization preserves metadata', () async {
      // Property: For any document, JSON serialization should preserve all fields

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Create document with random data
        final doc = Document.create(
          title: 'Document $i',
          category: DocumentCategory
              .values[random.nextInt(DocumentCategory.values.length)],
          date: random.nextBool() ? DateTime.now() : null,
          notes: random.nextBool() ? 'Notes $i' : null,
        );

        // Serialize to JSON and back
        final json = doc.toJson();
        final restored = Document.fromJson(json);

        // Verify all fields match
        expect(restored.syncId, equals(doc.syncId));
        expect(restored.title, equals(doc.title));
        expect(restored.category, equals(doc.category));
        expect(restored.date, equals(doc.date));
        expect(restored.notes, equals(doc.notes));
        expect(restored.createdAt, equals(doc.createdAt));
        expect(restored.updatedAt, equals(doc.updatedAt));
        expect(restored.syncState, equals(doc.syncState));
      }
    });

    test('Document database serialization preserves metadata', () async {
      // Property: For any document, database serialization should preserve all fields

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Create document with random data
        final doc = Document.create(
          title: 'Document $i',
          category: DocumentCategory
              .values[random.nextInt(DocumentCategory.values.length)],
          date: random.nextBool() ? DateTime.now() : null,
          notes: random.nextBool() ? 'Notes $i' : null,
        );

        // Serialize to database format and back
        final dbMap = doc.toDatabase();
        final restored = Document.fromDatabase(dbMap);

        // Verify all fields match
        expect(restored.syncId, equals(doc.syncId));
        expect(restored.title, equals(doc.title));
        expect(restored.category, equals(doc.category));
        expect(restored.notes, equals(doc.notes));
        expect(restored.syncState, equals(doc.syncState));

        // Dates should match (within millisecond precision)
        expect(restored.createdAt.millisecondsSinceEpoch,
            equals(doc.createdAt.millisecondsSinceEpoch));
        expect(restored.updatedAt.millisecondsSinceEpoch,
            equals(doc.updatedAt.millisecondsSinceEpoch));
        if (doc.date != null) {
          expect(restored.date!.millisecondsSinceEpoch,
              equals(doc.date!.millisecondsSinceEpoch));
        } else {
          expect(restored.date, isNull);
        }
      }
    });

    test('Document copyWith preserves unchanged metadata', () async {
      // Property: For any document, copyWith should preserve fields not explicitly changed

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Create original document
        final original = Document.create(
          title: 'Original $i',
          category: DocumentCategory
              .values[random.nextInt(DocumentCategory.values.length)],
          date: DateTime.now(),
          notes: 'Original notes',
        );

        // Create copy with only title changed
        final copy = original.copyWith(title: 'Modified $i');

        // Verify unchanged fields are preserved
        expect(copy.syncId, equals(original.syncId));
        expect(copy.category, equals(original.category));
        expect(copy.date, equals(original.date));
        expect(copy.notes, equals(original.notes));
        expect(copy.createdAt, equals(original.createdAt));
        expect(copy.updatedAt, equals(original.updatedAt));
        expect(copy.syncState, equals(original.syncState));

        // Verify changed field
        expect(copy.title, equals('Modified $i'));
      }
    });

    test('Document with special characters preserves metadata', () async {
      // Property: Special characters in metadata should be preserved

      const iterations = 100;
      final specialChars = [
        '!',
        '@',
        '#',
        '\$',
        '%',
        '&',
        '*',
        '(',
        ')',
        '-',
        '_',
        '+',
        '=',
        '/',
        '\\'
      ];

      for (int i = 0; i < iterations; i++) {
        final specialChar = specialChars[random.nextInt(specialChars.length)];
        final title = 'Document $specialChar $i';
        final notes =
            'Notes with special: $specialChar ${_generateRandomString(30)}';

        final doc = Document.create(
          title: title,
          category: DocumentCategory.other,
          notes: notes,
        );

        // Serialize and deserialize
        final json = doc.toJson();
        final restored = Document.fromJson(json);

        // Verify special characters preserved
        expect(restored.title, equals(title));
        expect(restored.notes, equals(notes));
      }
    });

    test('Document with empty notes preserves metadata', () async {
      // Property: Empty or null notes should be preserved correctly

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Alternate between null and empty string
        final notes = i % 2 == 0 ? null : '';

        final doc = Document.create(
          title: 'Document $i',
          category: DocumentCategory.other,
          notes: notes,
        );

        // Serialize and deserialize
        final json = doc.toJson();
        final restored = Document.fromJson(json);

        // Verify notes preserved correctly
        expect(restored.notes, equals(notes));
      }
    });

    test('Document timestamps are preserved with precision', () async {
      // Property: Timestamps should be preserved with millisecond precision

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        final doc = Document.create(
          title: 'Document $i',
          category: DocumentCategory.other,
        );

        // Serialize to database and back
        final dbMap = doc.toDatabase();
        final restored = Document.fromDatabase(dbMap);

        // Verify timestamps match exactly (millisecond precision)
        expect(restored.createdAt.millisecondsSinceEpoch,
            equals(doc.createdAt.millisecondsSinceEpoch));
        expect(restored.updatedAt.millisecondsSinceEpoch,
            equals(doc.updatedAt.millisecondsSinceEpoch));
      }
    });

    test('Document category is preserved correctly', () async {
      // Property: All category values should be preserved

      const iterations = 100;

      for (int i = 0; i < iterations; i++) {
        // Test each category type
        final category =
            DocumentCategory.values[i % DocumentCategory.values.length];

        final doc = Document.create(
          title: 'Document $i',
          category: category,
        );

        // Serialize and deserialize
        final json = doc.toJson();
        final restored = Document.fromJson(json);

        // Verify category preserved
        expect(restored.category, equals(category));
        expect(restored.category.displayName, equals(category.displayName));
      }
    });
  });
}

/// Generate a random string of specified length
String _generateRandomString(int length) {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ';
  final random = Random();
  return String.fromCharCodes(
    Iterable.generate(
        length, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
  );
}
