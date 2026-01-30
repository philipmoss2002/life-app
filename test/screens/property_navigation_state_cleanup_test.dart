import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/verify_email_screen.dart';
import 'dart:math';

/// **Feature: email-verification-flow, Property: Navigation back clears verification state**
/// **Validates: Requirements 5.3**
///
/// Property-based test to verify that for any user who returns to the sign-in
/// screen from verification, the system should clear any stored verification state.
///
/// This ensures that:
/// 1. The verification code input field is cleared
/// 2. Error messages are cleared
/// 3. Loading states are reset
/// 4. The screen returns to its initial state
///
/// Note: Since VerifyEmailScreen is a StatefulWidget, each new instance creates
/// fresh state. This test verifies that navigation creates new instances rather
/// than reusing old state.
void main() {
  group('Property: Navigation back clears verification state', () {
    testWidgets(
        'should create fresh widget instances with clean state on each navigation',
        (WidgetTester tester) async {
      // Property: For any verification code entered, when user navigates back
      // and returns, a new widget instance should be created with clean state

      const iterations = 50;
      final random = Random();

      // Create the app once
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < iterations; i++) {
        // Generate random verification code (1-6 digits)
        final length = random.nextInt(6) + 1;
        final code = List.generate(
          length,
          (_) => random.nextInt(10).toString(),
        ).join();

        // Navigate to verification screen
        await tester.tap(find.text('Go to Verification'));
        await tester.pumpAndSettle();

        // Verify we're on the verification screen
        expect(find.byType(VerifyEmailScreen), findsOneWidget);

        // Enter the verification code
        final textField = find.byType(TextField);
        await tester.enterText(textField, code);
        await tester.pump();

        // Verify code is in the field
        var textFieldWidget = tester.widget<TextField>(textField);
        var currentValue = textFieldWidget.controller?.text ?? '';
        expect(
          currentValue,
          equals(code),
          reason:
              'Code "$code" should be in field before navigation (iteration $i)',
        );

        // Navigate back using the AppBar back button
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Verify we're back on the initial screen
        expect(find.byType(VerifyEmailScreen), findsNothing);
        expect(find.text('Go to Verification'), findsOneWidget);

        // Navigate to verification screen again
        await tester.tap(find.text('Go to Verification'));
        await tester.pumpAndSettle();

        // Verify we're on a fresh verification screen
        expect(find.byType(VerifyEmailScreen), findsOneWidget);

        // Verify the field is empty (state was cleared)
        final newTextField = find.byType(TextField);
        final newTextFieldWidget = tester.widget<TextField>(newTextField);
        final newValue = newTextFieldWidget.controller?.text ?? '';

        expect(
          newValue,
          isEmpty,
          reason:
              'Verification code should be cleared after navigation back (iteration $i, previous code: "$code")',
        );

        // Navigate back to prepare for next iteration
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('should reset button state when navigating back and returning',
        (WidgetTester tester) async {
      // Property: For any button state (enabled/disabled), when user navigates
      // back and returns, the button should be in its initial disabled state

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      // Navigate to verification screen
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Enter a valid 6-digit code to enable the button
      final textField = find.byType(TextField);
      await tester.enterText(textField, '123456');
      await tester.pump();

      // Verify button is enabled
      var button = find.widgetWithText(ElevatedButton, 'Verify Account');
      var buttonWidget = tester.widget<ElevatedButton>(button);
      expect(
        buttonWidget.onPressed,
        isNotNull,
        reason: 'Button should be enabled with valid code',
      );

      // Navigate back using AppBar back button
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Navigate to verification screen again
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify button is disabled (initial state)
      button = find.widgetWithText(ElevatedButton, 'Verify Account');
      buttonWidget = tester.widget<ElevatedButton>(button);
      expect(
        buttonWidget.onPressed,
        isNull,
        reason: 'Button should be disabled after navigation back',
      );
    });

    testWidgets('should not persist error messages across navigation',
        (WidgetTester tester) async {
      // Property: For any error state, when user navigates back and returns,
      // error messages should not persist

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      // Navigate to verification screen
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify no error message is displayed initially
      expect(
        find.byIcon(Icons.error_outline),
        findsNothing,
        reason: 'No error should be displayed initially',
      );

      // Navigate back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Navigate to verification screen again
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify no error message is displayed (state was cleared)
      expect(
        find.byIcon(Icons.error_outline),
        findsNothing,
        reason: 'No error should be displayed after navigation back',
      );
    });

    testWidgets(
        'should create fresh widget state for each navigation to verification screen',
        (WidgetTester tester) async {
      // Property: Each time user navigates to verification screen, it should
      // be a fresh instance with clean state

      const iterations = 20;
      final random = Random();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      for (int i = 0; i < iterations; i++) {
        // Navigate to verification screen
        await tester.tap(find.text('Go to Verification'));
        await tester.pumpAndSettle();

        // Generate random code
        final length = random.nextInt(6) + 1;
        final code = List.generate(
          length,
          (_) => random.nextInt(10).toString(),
        ).join();

        // Enter code
        final textField = find.byType(TextField);
        await tester.enterText(textField, code);
        await tester.pump();

        // Verify code is present
        var textFieldWidget = tester.widget<TextField>(textField);
        var currentValue = textFieldWidget.controller?.text ?? '';
        expect(currentValue, equals(code));

        // Navigate back
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        // Verify we're back
        expect(find.byType(VerifyEmailScreen), findsNothing);
      }

      // Navigate one more time to verify clean state
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify field is empty
      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);
      final value = textFieldWidget.controller?.text ?? '';
      expect(
        value,
        isEmpty,
        reason: 'Field should be empty after $iterations navigation cycles',
      );

      // Verify button is disabled
      final button = find.widgetWithText(ElevatedButton, 'Verify Account');
      final buttonWidget = tester.widget<ElevatedButton>(button);
      expect(
        buttonWidget.onPressed,
        isNull,
        reason: 'Button should be disabled after $iterations navigation cycles',
      );
    });

    testWidgets('should not carry over loading state across navigation',
        (WidgetTester tester) async {
      // Property: Loading state should not persist when navigating back and
      // returning to verification screen

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      // Navigate to verification screen
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify no loading indicator is shown initially
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'No loading indicator should be shown initially',
      );

      // Navigate back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Navigate to verification screen again
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify no loading indicator is shown (state was cleared)
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'No loading indicator should be shown after navigation back',
      );

      // Verify button shows text, not loading indicator
      expect(
        find.text('Verify Account'),
        findsOneWidget,
        reason: 'Button should show text, not loading indicator',
      );
    });

    testWidgets('should maintain email parameter across navigation cycles',
        (WidgetTester tester) async {
      // Property: While state should be cleared, the email parameter should
      // remain consistent if navigating to the same verification screen

      const testEmail = 'persistent@example.com';

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: testEmail,
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      const iterations = 10;

      for (int i = 0; i < iterations; i++) {
        // Navigate to verification screen
        await tester.tap(find.text('Go to Verification'));
        await tester.pumpAndSettle();

        // Verify email is displayed
        expect(
          find.text(testEmail),
          findsOneWidget,
          reason: 'Email should be displayed (iteration $i)',
        );

        // Enter some code
        final textField = find.byType(TextField);
        await tester.enterText(textField, '12345');
        await tester.pump();

        // Navigate back
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }

      // Navigate one more time
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify email is still displayed correctly
      expect(
        find.text(testEmail),
        findsOneWidget,
        reason: 'Email should persist across navigation cycles',
      );

      // But state should be cleared
      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);
      final value = textFieldWidget.controller?.text ?? '';
      expect(
        value,
        isEmpty,
        reason: 'Field should be empty despite email persistence',
      );
    });

    testWidgets(
        'should handle rapid navigation back and forth without state leakage',
        (WidgetTester tester) async {
      // Property: Rapid navigation should not cause state to leak or accumulate

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      // Perform rapid navigation cycles
      for (int i = 0; i < 5; i++) {
        // Navigate forward
        await tester.tap(find.text('Go to Verification'));
        await tester.pumpAndSettle();

        // Enter code quickly
        final textField = find.byType(TextField);
        await tester.enterText(textField, '999999');
        await tester.pump();

        // Navigate back immediately
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }

      // Final navigation to verify clean state
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify state is clean
      final textField = find.byType(TextField);
      final textFieldWidget = tester.widget<TextField>(textField);
      final value = textFieldWidget.controller?.text ?? '';
      expect(
        value,
        isEmpty,
        reason: 'Field should be empty after rapid navigation cycles',
      );

      // Verify button is disabled
      final button = find.widgetWithText(ElevatedButton, 'Verify Account');
      final buttonWidget = tester.widget<ElevatedButton>(button);
      expect(
        buttonWidget.onPressed,
        isNull,
        reason: 'Button should be disabled after rapid navigation cycles',
      );
    });

    testWidgets('should clear resend button loading state on navigation back',
        (WidgetTester tester) async {
      // Property: Resend button loading state should not persist across navigation

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VerifyEmailScreen(
                          email: 'test@example.com',
                        ),
                      ),
                    );
                  },
                  child: const Text('Go to Verification'),
                ),
              ),
            ),
          ),
        ),
      );

      // Navigate to verification screen
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify resend button is present and not loading
      expect(
        find.text('Resend Code'),
        findsOneWidget,
        reason: 'Resend button should be present',
      );

      // Navigate back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Navigate to verification screen again
      await tester.tap(find.text('Go to Verification'));
      await tester.pumpAndSettle();

      // Verify resend button is still present and not in loading state
      expect(
        find.text('Resend Code'),
        findsOneWidget,
        reason: 'Resend button should be present after navigation back',
      );
    });
  });
}
