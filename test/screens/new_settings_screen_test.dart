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

    testWidgets('displays Account section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Verify Account section is present
      expect(find.text('Account'), findsOneWidget);
    });

    testWidgets('displays App section', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Verify App section is present
      expect(find.text('App'), findsOneWidget);
    });

    testWidgets('displays View Logs button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Verify View Logs button is present
      expect(find.text('View Logs'), findsOneWidget);
      expect(find.text('View app logs for debugging'), findsOneWidget);
    });

    testWidgets('displays App Version', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Verify App Version is present
      expect(find.text('App Version'), findsOneWidget);
    });

    testWidgets('does NOT display test features', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NewSettingsScreen(),
        ),
      );

      // Wait for data to load
      await tester.pumpAndSettle();

      // Verify NO test features are present
      expect(find.text('Subscription Debug'), findsNothing);
      expect(find.text('API Test'), findsNothing);
      expect(find.text('Detailed Sync Debug'), findsNothing);
      expect(find.text('S3 Direct Test'), findsNothing);
      expect(find.text('S3 Path Debug'), findsNothing);
      expect(find.text('Upload Download Test'), findsNothing);
      expect(find.text('Error Trace'), findsNothing);
      expect(find.text('Minimal Sync Test'), findsNothing);
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
  });
}
