import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/subscription_plans_screen.dart';
import 'package:household_docs_app/screens/subscription_status_screen.dart';

void main() {
  group('Subscription UI Tests', () {
    testWidgets('SubscriptionPlansScreen displays correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionPlansScreen(),
        ),
      );

      // Wait for the widget to build
      await tester.pump();

      // Verify the screen title is present
      expect(find.text('Premium Plans'), findsOneWidget);
    });

    testWidgets('SubscriptionStatusScreen displays correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SubscriptionStatusScreen(),
        ),
      );

      // Wait for the widget to build
      await tester.pump();

      // Verify the screen title is present
      expect(find.text('Subscription Status'), findsOneWidget);
    });
  });
}
