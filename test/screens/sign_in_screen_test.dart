import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/sign_in_screen.dart';

void main() {
  group('SignInScreen Widget Tests', () {
    testWidgets('should display all required UI elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Verify app bar
      expect(find.text('Sign In'), findsOneWidget);

      // Verify icon
      expect(find.byIcon(Icons.cloud_sync), findsOneWidget);

      // Verify title and subtitle
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(
        find.text('Sign in to access your documents across devices'),
        findsOneWidget,
      );

      // Verify form fields
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Verify buttons
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.text("Don't have an account?"), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Continue without account'), findsOneWidget);
    });

    testWidgets('should validate empty email field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Tap sign in button without entering email
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('should validate empty password field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Enter email but not password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );

      // Tap sign in button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('should toggle password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Find password field
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      expect(passwordField, findsOneWidget);

      // Find visibility toggle button
      final visibilityButton = find.descendant(
        of: passwordField,
        matching: find.byType(IconButton),
      );
      expect(visibilityButton, findsOneWidget);

      // Tap to toggle visibility
      await tester.tap(visibilityButton);
      await tester.pump();

      // Verify icon changed (visibility_off to visibility)
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('should navigate to sign up screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Tap sign up button
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      // Verify navigation to sign up screen
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('should navigate back when continue without account is tapped',
        (WidgetTester tester) async {
      bool popped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignInScreen(),
                  ),
                );
                if (result == null) popped = true;
              },
              child: const Text('Go to Sign In'),
            ),
          ),
        ),
      );

      // Navigate to sign in screen
      await tester.tap(find.text('Go to Sign In'));
      await tester.pumpAndSettle();

      // Tap continue without account
      await tester.tap(find.text('Continue without account'));
      await tester.pumpAndSettle();

      // Verify navigation back
      expect(popped, true);
    });

    testWidgets('should disable form fields while loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignInScreen(),
        ),
      );

      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );

      // Tap sign in button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();

      // Verify loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
