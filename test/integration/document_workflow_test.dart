import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/main.dart';

void main() {
  group('Document Workflow Integration Tests', () {
    testWidgets('Complete document creation workflow',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      // Verify we're on home screen
      expect(find.text('Household Documents'), findsOneWidget);

      // Tap add button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify we're on add document screen
      expect(find.text('Add Document'), findsOneWidget);

      // Enter document title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Home Insurance',
      );

      // Select category
      await tester.tap(find.text('Home Insurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car Insurance').last);
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        'Test notes for insurance',
      );

      // Save document
      await tester.tap(find.text('Save Document'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should navigate to document detail screen
      expect(find.text('Document Details'), findsOneWidget);
      expect(find.text('Test Home Insurance'), findsOneWidget);
    });

    testWidgets('Filter documents by category', (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      // Tap on Holiday category filter
      await tester.tap(find.text('Holiday'));
      await tester.pumpAndSettle();

      // Verify Holiday chip is selected
      final holidayChip = tester.widget<FilterChip>(
        find.ancestor(
          of: find.text('Holiday'),
          matching: find.byType(FilterChip),
        ),
      );
      expect(holidayChip.selected, isTrue);
    });

    testWidgets('Navigate to upcoming renewals screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      // Tap upcoming renewals icon
      await tester.tap(find.byIcon(Icons.notifications_active));
      await tester.pumpAndSettle();

      // Verify we're on upcoming renewals screen
      expect(find.text('Upcoming Renewals'), findsOneWidget);
    });

    testWidgets('Back navigation should work correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      // Navigate to add document screen
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Document'), findsOneWidget);

      // Go back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Should be back on home screen
      expect(find.text('Household Documents'), findsOneWidget);
    });
  });

  group('Category Label Tests', () {
    testWidgets('Holiday category shows Payment Due label',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Select Holiday category
      await tester.tap(find.text('Home Insurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Holiday').last);
      await tester.pumpAndSettle();

      expect(find.text('Payment Due'), findsOneWidget);
    });

    testWidgets('Other category shows Date label', (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Select Other category
      await tester.tap(find.text('Home Insurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('Insurance categories show Renewal Date label',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HouseholdDocsApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Home Insurance is selected by default
      expect(find.text('Renewal Date'), findsOneWidget);
    });
  });
}
