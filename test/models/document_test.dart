import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/document.dart';

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
}
