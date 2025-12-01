import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/add_document_screen.dart';

void main() {
  group('Add Document Screen Tests', () {
    testWidgets('Add document screen should display all form fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      expect(find.text('Add Document'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Renewal Date'), findsOneWidget);
      expect(find.text('Attach File'), findsOneWidget);
      expect(find.text('Notes (optional)'), findsOneWidget);
      expect(find.text('Save Document'), findsOneWidget);
    });

    testWidgets('Title field should be required', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      // Try to save without entering title
      await tester.tap(find.text('Save Document'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a title'), findsOneWidget);
    });

    testWidgets('Category dropdown should show all categories',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      // Tap on category dropdown
      await tester.tap(find.text('Home Insurance'));
      await tester.pumpAndSettle();

      expect(find.text('Home Insurance').hitTestable(), findsWidgets);
      expect(find.text('Car Insurance').hitTestable(), findsOneWidget);
      expect(find.text('Mortgage').hitTestable(), findsOneWidget);
      expect(find.text('Holiday').hitTestable(), findsOneWidget);
      expect(find.text('Other').hitTestable(), findsOneWidget);
    });

    testWidgets('Holiday category should show "Payment Due" label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      // Select Holiday category
      await tester.tap(find.text('Home Insurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Holiday').last);
      await tester.pumpAndSettle();

      expect(find.text('Payment Due'), findsOneWidget);
    });

    testWidgets('Other category should show "Date" label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      // Select Other category
      await tester.tap(find.text('Home Insurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other').last);
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
    });

    testWidgets('Title field should accept text input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'Test Insurance Policy',
      );

      expect(find.text('Test Insurance Policy'), findsOneWidget);
    });

    testWidgets('Notes field should accept multiline text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Notes (optional)'),
        'Line 1\nLine 2\nLine 3',
      );

      expect(find.text('Line 1\nLine 2\nLine 3'), findsOneWidget);
    });

    testWidgets('Date picker should open when tapping date field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddDocumentScreen(),
        ),
      );

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
