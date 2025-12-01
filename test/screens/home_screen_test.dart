import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/home_screen.dart';

void main() {
  group('Home Screen Tests', () {
    testWidgets('Home screen should display title',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.text('Household Documents'), findsOneWidget);
    });

    testWidgets('Home screen should display category filters',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Home Insurance'), findsOneWidget);
      expect(find.text('Car Insurance'), findsOneWidget);
      expect(find.text('Mortgage'), findsOneWidget);
      expect(find.text('Holiday'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);
    });

    testWidgets('Home screen should display add button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('Home screen should display upcoming renewals icon',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });

    testWidgets('Home screen should display empty state when no documents',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No documents yet'), findsOneWidget);
      expect(find.text('Tap + to add your first document'), findsOneWidget);
    });

    testWidgets('Tapping add button should navigate to add document screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Add Document'), findsOneWidget);
    });

    testWidgets('Category filter should be selectable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Holiday category
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
  });
}
