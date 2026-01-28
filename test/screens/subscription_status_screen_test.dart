import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/subscription_status_screen.dart';

void main() {
  group('SubscriptionStatusScreen UI Tests', () {
    testWidgets('displays loading state initially',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays no subscription status correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();

      // Should show "Local Storage Only" title
      expect(find.text('Local Storage Only'), findsOneWidget);

      // Should show cloud sync disabled indicator
      expect(find.text('Cloud Sync Disabled'), findsOneWidget);

      // Should show cloud_off icon
      expect(find.byIcon(Icons.cloud_off), findsWidgets);

      // Should show restore purchases button
      expect(find.text('Restore Purchases'), findsOneWidget);

      // Should NOT show manage subscription button for no subscription
      expect(find.text('Manage Subscription'), findsNothing);
    });

    testWidgets('displays subscription details section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show subscription details heading
      expect(find.text('Subscription Details'), findsOneWidget);

      // Should show status detail
      expect(find.text('Status'), findsOneWidget);

      // Should show cloud sync detail
      expect(find.text('Cloud Sync'), findsOneWidget);

      // Should show expiration date detail
      expect(find.text('Expiration Date'), findsOneWidget);

      // Should show billing detail
      expect(find.text('Billing'), findsOneWidget);
    });

    testWidgets('restore purchases button is present and tappable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find restore purchases button
      final restoreButton = find.text('Restore Purchases');
      expect(restoreButton, findsOneWidget);

      // Verify it's tappable (this will trigger the restore flow)
      await tester.tap(restoreButton);
      await tester.pump();

      // Should show loading indicator on button after tap
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays cloud sync status in details section',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Cloud Sync in details
      expect(find.text('Cloud Sync'), findsOneWidget);

      // For no subscription, should show Disabled
      expect(find.text('Disabled'), findsOneWidget);
    });

    testWidgets('displays info box with platform-specific text',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Should show info icon
      expect(find.byIcon(Icons.info_outline), findsWidgets);

      // Should show text about managing subscription
      expect(find.textContaining('subscription'), findsWidgets);
    });

    testWidgets('status card has appropriate visual elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find the status card container
      final containerFinder = find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsWidgets);
    });

    testWidgets('displays appropriate icon for subscription status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // For no subscription, should show cloud_off icon
      expect(find.byIcon(Icons.cloud_off), findsWidgets);
    });
  });
}
