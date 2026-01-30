import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/new_settings_screen.dart';

void main() {
  group('NewSettingsScreen', () {
    testWidgets('displays settings title in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Verify app bar title
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('shows loading indicator initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    group('Subscription Section Tests (Task 8.1)', () {
      testWidgets('displays subscription status after loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify subscription status is displayed
        expect(find.text('Status'), findsOneWidget);
      });

      testWidgets('displays cloud sync status after loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify cloud sync status is displayed
        expect(find.text('Cloud Sync'), findsOneWidget);
      });

      testWidgets('displays View Subscription button after loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify View Subscription button is present
        expect(find.text('View Subscription'), findsOneWidget);
        expect(find.byIcon(Icons.card_membership), findsOneWidget);
      });

      testWidgets('navigates to subscription status screen when button tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap the View Subscription button
        await tester.tap(find.text('View Subscription'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify navigation to subscription status screen
        expect(find.text('Subscription Status'), findsOneWidget);
      });

      testWidgets('navigates to subscription status screen when status tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap the Status list tile
        await tester.tap(find.text('Status'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify navigation to subscription status screen
        expect(find.text('Subscription Status'), findsOneWidget);
      });

      testWidgets('displays subscription section after loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify Subscription section header is present
        expect(find.text('Subscription'), findsOneWidget);
      });

      testWidgets('displays cloud sync icon after loading',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: NewSettingsScreen(),
          ),
        );

        // Wait for loading to complete
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify that a cloud sync icon is present (either cloud_done or cloud_off)
        final cloudDoneIcon = find.byIcon(Icons.cloud_done);
        final cloudOffIcon = find.byIcon(Icons.cloud_off);

        expect(
          cloudDoneIcon.evaluate().isNotEmpty ||
              cloudOffIcon.evaluate().isNotEmpty,
          isTrue,
          reason: 'Should display either cloud_done or cloud_off icon',
        );
      });
    });
  });
}
