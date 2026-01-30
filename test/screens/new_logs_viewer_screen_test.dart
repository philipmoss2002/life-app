import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/screens/new_logs_viewer_screen.dart';
import 'package:household_docs_app/services/log_service.dart';

void main() {
  late LogService logService;

  setUp(() {
    logService = LogService();
    logService.clearLogs();
  });

  tearDown(() {
    logService.clearLogs();
  });

  Widget createTestWidget() {
    return const MaterialApp(
      home: NewLogsViewerScreen(),
    );
  }

  group('NewLogsViewerScreen', () {
    testWidgets('displays app bar with title and action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('App Logs'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('displays filter chips for log levels',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Debug'), findsOneWidget);
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Warning'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('displays empty state when no logs available',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('No logs available'), findsOneWidget);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    });

    testWidgets('displays logs when available', (WidgetTester tester) async {
      // Add some test logs
      logService.log('Test info message', level: LogLevel.info);
      logService.log('Test warning message', level: LogLevel.warning);
      logService.log('Test error message', level: LogLevel.error);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Test info message'), findsOneWidget);
      expect(find.text('Test warning message'), findsOneWidget);
      expect(find.text('Test error message'), findsOneWidget);
    });

    testWidgets('displays correct icons for log levels',
        (WidgetTester tester) async {
      logService.log('Info message', level: LogLevel.info);
      logService.log('Warning message', level: LogLevel.warning);
      logService.log('Error message', level: LogLevel.error);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('filters logs by level when filter chip is selected',
        (WidgetTester tester) async {
      logService.log('Info message', level: LogLevel.info);
      logService.log('Warning message', level: LogLevel.warning);
      logService.log('Error message', level: LogLevel.error);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Initially all logs are visible
      expect(find.text('Info message'), findsOneWidget);
      expect(find.text('Warning message'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);

      // Tap on Error filter chip
      await tester.tap(find.text('Error'));
      await tester.pump();

      // Only error logs should be visible
      expect(find.text('Info message'), findsNothing);
      expect(find.text('Warning message'), findsNothing);
      expect(find.text('Error message'), findsOneWidget);
    });

    testWidgets('shows all logs when All filter is selected',
        (WidgetTester tester) async {
      logService.log('Info message', level: LogLevel.info);
      logService.log('Error message', level: LogLevel.error);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Select Error filter
      await tester.tap(find.text('Error'));
      await tester.pump();

      expect(find.text('Info message'), findsNothing);
      expect(find.text('Error message'), findsOneWidget);

      // Select All filter
      await tester.tap(find.text('All'));
      await tester.pump();

      // All logs should be visible again
      expect(find.text('Info message'), findsOneWidget);
      expect(find.text('Error message'), findsOneWidget);
    });

    testWidgets('shows confirmation dialog when clear button is tapped',
        (WidgetTester tester) async {
      logService.log('Test message', level: LogLevel.info);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Clear Logs'), findsOneWidget);
      expect(find.text('Are you sure you want to clear all logs?'),
          findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('clears logs when confirmed', (WidgetTester tester) async {
      logService.log('Test message', level: LogLevel.info);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Test message'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Confirm clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Logs should be cleared
      expect(find.text('Test message'), findsNothing);
      expect(find.text('No logs available'), findsOneWidget);
      expect(find.text('Logs cleared'), findsOneWidget);
    });

    testWidgets('does not clear logs when cancelled',
        (WidgetTester tester) async {
      logService.log('Test message', level: LogLevel.info);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('Test message'), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Cancel clear
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Logs should still be there
      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('displays relative timestamps for recent logs',
        (WidgetTester tester) async {
      logService.log('Recent message', level: LogLevel.info);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Should show relative time like "0s ago" or "1s ago"
      expect(find.textContaining('ago'), findsAtLeastNWidgets(1));
    });

    testWidgets('copy button exists and can be tapped',
        (WidgetTester tester) async {
      logService.log('Test message', level: LogLevel.info);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Copy button should exist
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byTooltip('Copy Logs'), findsOneWidget);

      // Should be able to tap it without errors
      await tester.tap(find.byIcon(Icons.copy));
      await tester.pump();
    });
  });

  group('NewLogsViewerScreen - Requirements Verification', () {
    testWidgets('Requirement 9.1: Settings screen has View Logs option',
        (WidgetTester tester) async {
      // This is tested in new_settings_screen_test.dart
      // Logs viewer screen exists and can be navigated to
      await tester.pumpWidget(createTestWidget());
      expect(find.byType(NewLogsViewerScreen), findsOneWidget);
    });

    testWidgets('Requirement 9.2: Displays logs with timestamps and levels',
        (WidgetTester tester) async {
      logService.log('Info log', level: LogLevel.info);
      logService.log('Warning log', level: LogLevel.warning);
      logService.log('Error log', level: LogLevel.error);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Logs are displayed
      expect(find.text('Info log'), findsOneWidget);
      expect(find.text('Warning log'), findsOneWidget);
      expect(find.text('Error log'), findsOneWidget);

      // Timestamps are displayed (relative format)
      expect(find.textContaining('ago'), findsAtLeastNWidgets(3));

      // Level icons are displayed
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('Requirement 9.3: Supports filtering by severity level',
        (WidgetTester tester) async {
      logService.log('Info log', level: LogLevel.info);
      logService.log('Warning log', level: LogLevel.warning);
      logService.log('Error log', level: LogLevel.error);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Filter by Info
      await tester.tap(find.text('Info'));
      await tester.pump();
      expect(find.text('Info log'), findsOneWidget);
      expect(find.text('Warning log'), findsNothing);
      expect(find.text('Error log'), findsNothing);

      // Filter by Warning
      await tester.tap(find.text('Warning'));
      await tester.pump();
      expect(find.text('Info log'), findsNothing);
      expect(find.text('Warning log'), findsOneWidget);
      expect(find.text('Error log'), findsNothing);

      // Filter by Error
      await tester.tap(find.text('Error'));
      await tester.pump();
      expect(find.text('Info log'), findsNothing);
      expect(find.text('Warning log'), findsNothing);
      expect(find.text('Error log'), findsOneWidget);
    });

    testWidgets('Requirement 9.4: Provides copy and share options',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Copy button exists
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byTooltip('Copy Logs'), findsOneWidget);

      // Share button exists
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byTooltip('Share Logs'), findsOneWidget);

      // Clear button exists
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byTooltip('Clear Logs'), findsOneWidget);
    });
  });
}
