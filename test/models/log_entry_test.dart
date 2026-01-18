import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/log_entry.dart';

void main() {
  group('LogLevel', () {
    test('has all expected values', () {
      expect(LogLevel.values.length, equals(3));
      expect(LogLevel.values, contains(LogLevel.info));
      expect(LogLevel.values, contains(LogLevel.warning));
      expect(LogLevel.values, contains(LogLevel.error));
    });

    test('description returns human-readable text', () {
      expect(LogLevel.info.description, equals('Info'));
      expect(LogLevel.warning.description, equals('Warning'));
      expect(LogLevel.error.description, equals('Error'));
    });

    test('severity returns correct values', () {
      expect(LogLevel.info.severity, equals(0));
      expect(LogLevel.warning.severity, equals(1));
      expect(LogLevel.error.severity, equals(2));
    });

    test('severity allows sorting by importance', () {
      final levels = [LogLevel.error, LogLevel.info, LogLevel.warning];
      levels.sort((a, b) => a.severity.compareTo(b.severity));

      expect(levels, equals([LogLevel.info, LogLevel.warning, LogLevel.error]));
    });
  });

  group('LogEntry', () {
    test('creates log entry with all fields', () {
      final now = DateTime.now();
      final entry = LogEntry(
        id: 1,
        timestamp: now,
        level: LogLevel.error,
        message: 'Test message',
        errorDetails: 'Error details',
        stackTrace: 'Stack trace',
      );

      expect(entry.id, equals(1));
      expect(entry.timestamp, equals(now));
      expect(entry.level, equals(LogLevel.error));
      expect(entry.message, equals('Test message'));
      expect(entry.errorDetails, equals('Error details'));
      expect(entry.stackTrace, equals('Stack trace'));
    });

    test('create factory generates entry with current timestamp', () {
      final entry = LogEntry.create(
        level: LogLevel.info,
        message: 'Test message',
      );

      expect(entry.timestamp, isNotNull);
      expect(entry.level, equals(LogLevel.info));
      expect(entry.message, equals('Test message'));
      expect(entry.id, isNull);
    });

    test('info factory creates info log entry', () {
      final entry = LogEntry.info('Info message');

      expect(entry.level, equals(LogLevel.info));
      expect(entry.message, equals('Info message'));
      expect(entry.errorDetails, isNull);
      expect(entry.stackTrace, isNull);
    });

    test('warning factory creates warning log entry', () {
      final entry = LogEntry.warning('Warning message');

      expect(entry.level, equals(LogLevel.warning));
      expect(entry.message, equals('Warning message'));
    });

    test('error factory creates error log entry', () {
      final entry = LogEntry.error(
        'Error message',
        errorDetails: 'Details',
        stackTrace: 'Trace',
      );

      expect(entry.level, equals(LogLevel.error));
      expect(entry.message, equals('Error message'));
      expect(entry.errorDetails, equals('Details'));
      expect(entry.stackTrace, equals('Trace'));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = LogEntry.info('Original');
      final updated = original.copyWith(
        level: LogLevel.error,
        message: 'Updated',
      );

      expect(updated.level, equals(LogLevel.error));
      expect(updated.message, equals('Updated'));
      expect(updated.timestamp, equals(original.timestamp));
    });

    test('toJson and fromJson round trip', () {
      final original = LogEntry(
        id: 1,
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Test message',
        errorDetails: 'Error details',
        stackTrace: 'Stack trace',
      );

      final json = original.toJson();
      final restored = LogEntry.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        equals(original.timestamp.millisecondsSinceEpoch),
      );
      expect(restored.level, equals(original.level));
      expect(restored.message, equals(original.message));
      expect(restored.errorDetails, equals(original.errorDetails));
      expect(restored.stackTrace, equals(original.stackTrace));
    });

    test('toDatabase and fromDatabase round trip', () {
      final original = LogEntry(
        id: 1,
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Test message',
        errorDetails: 'Error details',
        stackTrace: 'Stack trace',
      );

      final dbMap = original.toDatabase();
      final restored = LogEntry.fromDatabase(dbMap);

      expect(restored.id, equals(original.id));
      expect(
        restored.timestamp.millisecondsSinceEpoch,
        equals(original.timestamp.millisecondsSinceEpoch),
      );
      expect(restored.level, equals(original.level));
      expect(restored.message, equals(original.message));
      expect(restored.errorDetails, equals(original.errorDetails));
      expect(restored.stackTrace, equals(original.stackTrace));
    });

    test('toDatabase uses snake_case for column names', () {
      final entry = LogEntry.error(
        'Test',
        errorDetails: 'Details',
        stackTrace: 'Trace',
      );

      final dbMap = entry.toDatabase();

      expect(dbMap.containsKey('error_details'), isTrue);
      expect(dbMap.containsKey('stack_trace'), isTrue);
      expect(dbMap['error_details'], equals('Details'));
      expect(dbMap['stack_trace'], equals('Trace'));
    });

    test('format returns readable string', () {
      final entry = LogEntry.error(
        'Test message',
        errorDetails: 'Error details',
        stackTrace: 'Stack trace',
      );

      final formatted = entry.format();

      expect(formatted, contains('[ERROR]'));
      expect(formatted, contains('Test message'));
      expect(formatted, contains('Error: Error details'));
      expect(formatted, contains('Stack Trace:'));
      expect(formatted, contains('Stack trace'));
    });

    test('format handles null error details and stack trace', () {
      final entry = LogEntry.info('Test message');

      final formatted = entry.format();

      expect(formatted, contains('[INFO]'));
      expect(formatted, contains('Test message'));
      expect(formatted, isNot(contains('Error:')));
      expect(formatted, isNot(contains('Stack Trace:')));
    });

    test('equality operator works correctly', () {
      final now = DateTime.now();
      final entry1 = LogEntry(
        id: 1,
        timestamp: now,
        level: LogLevel.info,
        message: 'Test',
      );
      final entry2 = LogEntry(
        id: 1,
        timestamp: now,
        level: LogLevel.info,
        message: 'Test',
      );
      final entry3 = LogEntry.error('Different');

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });

    test('hashCode is consistent', () {
      final now = DateTime.now();
      final entry1 = LogEntry(
        timestamp: now,
        level: LogLevel.info,
        message: 'Test',
      );
      final entry2 = LogEntry(
        timestamp: now,
        level: LogLevel.info,
        message: 'Test',
      );

      expect(entry1.hashCode, equals(entry2.hashCode));
    });

    test('toString provides useful information', () {
      final entry = LogEntry.error('Test message');

      final str = entry.toString();

      expect(str, contains('LogEntry'));
      expect(str, contains('error'));
      expect(str, contains('Test message'));
    });

    test('handles null optional fields in JSON round trip', () {
      final original = LogEntry.info('Test');

      final json = original.toJson();
      final restored = LogEntry.fromJson(json);

      expect(restored.errorDetails, isNull);
      expect(restored.stackTrace, isNull);
    });

    test('handles null optional fields in database round trip', () {
      final original = LogEntry.info('Test');

      final dbMap = original.toDatabase();
      final restored = LogEntry.fromDatabase(dbMap);

      expect(restored.errorDetails, isNull);
      expect(restored.stackTrace, isNull);
    });

    test('toDatabase excludes id when null', () {
      final entry = LogEntry.info('Test');

      final dbMap = entry.toDatabase();

      expect(dbMap.containsKey('id'), isFalse);
    });

    test('toDatabase includes id when present', () {
      final entry = LogEntry(
        id: 42,
        timestamp: DateTime.now(),
        level: LogLevel.info,
        message: 'Test',
      );

      final dbMap = entry.toDatabase();

      expect(dbMap['id'], equals(42));
    });
  });
}
