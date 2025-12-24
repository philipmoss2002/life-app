import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/main.dart';
import 'test_helpers.dart';

void main() {
  setUpAll(() {
    setupWidgetTest();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HouseholdDocsApp());
    await tester.pumpAndSettle();

    // Verify that the home screen loads
    expect(find.text('Your Reminders'), findsOneWidget);
  });
}
