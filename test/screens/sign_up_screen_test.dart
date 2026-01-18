import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/sign_up_screen.dart';

void main() {
  group('SignUpScreen Widget Tests', () {
    testWidgets('should display all required UI elements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Verify app bar
      expect(find.text('Create Account'), findsOneWidget);

      // Verify icon
      expect(find.byIcon(Icons.cloud_upload), findsOneWidget);

      // Verify title and subtitle
      expect(find.text('Sign Up for Cloud Sync'), findsOneWidget);
      expect(
        find.text('Create an account to sync your documents across devices'),
        findsOneWidget,
      );

      // Verify form fields
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);

      // Verify password requirements
      expect(find.text('Password Requirements:'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      expect(find.text('One uppercase letter'), findsOneWidget);
      expect(find.text('One lowercase letter'), findsOneWidget);
      expect(find.text('One number'), findsOneWidget);

      // Verify buttons
      expect(
        find.widgetWithText(ElevatedButton, 'Create Account'),
        findsOneWidget,
      );
      expect(find.text('Already have an account?'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('should validate empty email field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Tap create account button without entering email
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Please enter your email'), findsOneWidget);
    });

    testWidgets('should validate invalid email format',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'invalid-email',
      );

      // Tap create account button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });

    testWidgets('should validate empty password field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Enter email but not password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );

      // Tap create account button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Please enter a password'), findsOneWidget);
    });

    testWidgets('should validate password strength requirements',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Enter email and weak password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'weak',
      );

      // Tap create account button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Password does not meet requirements'), findsOneWidget);
    });

    testWidgets('should update password strength indicators',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Initially all requirements should be unmet (circle_outlined icons)
      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // Enter password that meets length requirement
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password',
      );
      await tester.pump();

      // Should have at least one check mark (length + lowercase)
      expect(find.byIcon(Icons.check_circle), findsWidgets);

      // Enter strong password
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password123',
      );
      await tester.pump();

      // All requirements should be met
      expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });

    testWidgets('should validate password confirmation mismatch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Enter email and passwords that don't match
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'DifferentPassword123',
      );

      // Tap create account button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pumpAndSettle();

      // Verify validation error
      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('should toggle password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Find password field
      final passwordField = find.widgetWithText(TextFormField, 'Password');
      expect(passwordField, findsOneWidget);

      // Find visibility toggle button for password field
      final visibilityButtons = find.descendant(
        of: passwordField,
        matching: find.byType(IconButton),
      );
      expect(visibilityButtons, findsOneWidget);

      // Tap to toggle visibility
      await tester.tap(visibilityButtons.first);
      await tester.pump();

      // Verify icon changed
      expect(
          find.byIcon(Icons.visibility_off_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets('should toggle confirm password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Find confirm password field
      final confirmPasswordField =
          find.widgetWithText(TextFormField, 'Confirm Password');
      expect(confirmPasswordField, findsOneWidget);

      // Find visibility toggle button for confirm password field
      final visibilityButtons = find.descendant(
        of: confirmPasswordField,
        matching: find.byType(IconButton),
      );
      expect(visibilityButtons, findsOneWidget);

      // Tap to toggle visibility
      await tester.tap(visibilityButtons.first);
      await tester.pump();

      // Verify icon changed
      expect(
          find.byIcon(Icons.visibility_off_outlined), findsAtLeastNWidgets(1));
    });

    testWidgets('should navigate back to sign in screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Tap sign in button
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // Verify navigation back (sign up screen should be gone)
      expect(find.text('Create Account'), findsNothing);
    });

    testWidgets('should disable form fields while loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignUpScreen(),
        ),
      );

      // Enter valid credentials
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'Password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirm Password'),
        'Password123',
      );

      // Tap create account button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Create Account'));
      await tester.pump();

      // Verify loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
