import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/new_document_detail_screen.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('NewDocumentDetailScreen', () {
    testWidgets('displays "New Document" title when creating new document',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewDocumentDetailScreen(document: null),
        ),
      );

      // Verify title for new document
      expect(find.text('New Document'), findsOneWidget);
    });

    testWidgets(
        'displays "Document Details" title when viewing existing document',
        (WidgetTester tester) async {
      final document = Document(
        syncId: 'test-123',
        title: 'Test Document',
        description: 'Test description',
        labels: ['label1', 'label2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.synced,
        files: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewDocumentDetailScreen(document: document),
        ),
      );

      // Verify title for existing document
      expect(find.text('Document Details'), findsOneWidget);
    });

    testWidgets('shows edit and delete buttons for existing document',
        (WidgetTester tester) async {
      final document = Document(
        syncId: 'test-123',
        title: 'Test Document',
        description: null,
        labels: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.synced,
        files: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewDocumentDetailScreen(document: document),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Verify edit and delete buttons are present
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('shows form fields when creating new document',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewDocumentDetailScreen(document: null),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Verify form fields are present
      expect(
          find.byType(TextFormField), findsAtLeast(2)); // Title and description
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Description (optional)'), findsOneWidget);
    });

    testWidgets('displays document information in view mode',
        (WidgetTester tester) async {
      final document = Document(
        syncId: 'test-123',
        title: 'Test Document',
        description: 'Test description',
        labels: ['Work', 'Important'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        syncState: SyncState.synced,
        files: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: NewDocumentDetailScreen(document: document),
        ),
      );

      // Wait for the screen to load
      await tester.pumpAndSettle();

      // Verify document information is displayed
      expect(find.text('Test Document'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);
    });
  });
}
