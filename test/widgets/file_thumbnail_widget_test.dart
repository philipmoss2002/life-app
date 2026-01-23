import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/file_attachment.dart';
import 'package:household_docs_app/widgets/file_thumbnail_widget.dart';

void main() {
  group('FileThumbnailWidget', () {
    testWidgets('displays icon thumbnail for non-image files',
        (WidgetTester tester) async {
      final file = FileAttachment(
        fileName: 'document.pdf',
        localPath: null,
        s3Key: null,
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileThumbnailWidget(file: file),
          ),
        ),
      );

      // Should show a container with icon
      expect(find.byType(Container), findsWidgets);
      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('displays correct icon for PDF files',
        (WidgetTester tester) async {
      final file = FileAttachment(
        fileName: 'document.pdf',
        localPath: null,
        s3Key: null,
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileThumbnailWidget(file: file),
          ),
        ),
      );

      // Should show PDF icon
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets('displays correct icon for document files',
        (WidgetTester tester) async {
      final file = FileAttachment(
        fileName: 'document.docx',
        localPath: null,
        s3Key: null,
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileThumbnailWidget(file: file),
          ),
        ),
      );

      // Should show document icon
      expect(find.byIcon(Icons.description), findsOneWidget);
    });

    testWidgets('displays correct icon for spreadsheet files',
        (WidgetTester tester) async {
      final file = FileAttachment(
        fileName: 'spreadsheet.xlsx',
        localPath: null,
        s3Key: null,
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileThumbnailWidget(file: file),
          ),
        ),
      );

      // Should show table chart icon
      expect(find.byIcon(Icons.table_chart), findsOneWidget);
    });

    testWidgets('uses custom size when provided', (WidgetTester tester) async {
      final file = FileAttachment(
        fileName: 'document.pdf',
        localPath: null,
        s3Key: null,
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileThumbnailWidget(file: file, size: 100),
          ),
        ),
      );

      // Widget should render without errors
      expect(find.byType(FileThumbnailWidget), findsOneWidget);
    });

    testWidgets('displays icon for image files without local path',
        (WidgetTester tester) async {
      final file = FileAttachment(
        fileName: 'photo.jpg',
        localPath: null, // No local path
        s3Key: 's3://bucket/photo.jpg',
        fileSize: 1024,
        addedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileThumbnailWidget(file: file),
          ),
        ),
      );

      // Should show image icon as placeholder
      expect(find.byIcon(Icons.image), findsOneWidget);
    });
  });
}
