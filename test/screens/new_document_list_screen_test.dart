import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/new_document_list_screen.dart';

void main() {
  group('NewDocumentListScreen', () {
    testWidgets('displays app bar with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewDocumentListScreen(),
        ),
      );

      // Verify app bar title
      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets('displays settings button in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewDocumentListScreen(),
        ),
      );

      // Verify settings button
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('displays floating action button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewDocumentListScreen(),
        ),
      );

      // Verify FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('displays sign in prompt when not authenticated',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewDocumentListScreen(),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();

      // Should show sign in prompt
      expect(find.text('Sign In to Sync'), findsOneWidget);
      expect(
          find.text(
              'Sign in to sync your documents across devices and access them anywhere'),
          findsOneWidget);
    });
  });
}
