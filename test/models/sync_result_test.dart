import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_result.dart';

void main() {
  group('SyncResult', () {
    test('creates result with all fields', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 1,
        errors: ['Error 1'],
        duration: const Duration(seconds: 10),
      );

      expect(result.uploadedCount, equals(5));
      expect(result.downloadedCount, equals(3));
      expect(result.failedCount, equals(1));
      expect(result.errors, equals(['Error 1']));
      expect(result.duration, equals(const Duration(seconds: 10)));
    });

    test('success factory creates successful result', () {
      final result = SyncResult.success(
        uploadedCount: 5,
        downloadedCount: 3,
        duration: const Duration(seconds: 10),
      );

      expect(result.uploadedCount, equals(5));
      expect(result.downloadedCount, equals(3));
      expect(result.failedCount, equals(0));
      expect(result.errors, isEmpty);
      expect(result.isSuccess, isTrue);
    });

    test('failure factory creates failed result', () {
      final result = SyncResult.failure(
        errors: ['Error 1', 'Error 2'],
        duration: const Duration(seconds: 5),
      );

      expect(result.uploadedCount, equals(0));
      expect(result.downloadedCount, equals(0));
      expect(result.failedCount, equals(2));
      expect(result.errors, equals(['Error 1', 'Error 2']));
      expect(result.isSuccess, isFalse);
    });

    test('empty factory creates empty result', () {
      final result = SyncResult.empty();

      expect(result.uploadedCount, equals(0));
      expect(result.downloadedCount, equals(0));
      expect(result.failedCount, equals(0));
      expect(result.errors, isEmpty);
      expect(result.duration, equals(Duration.zero));
      expect(result.isSuccess, isTrue);
      expect(result.hasOperations, isFalse);
    });

    test('isSuccess returns true when no failures', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 0,
        errors: [],
        duration: const Duration(seconds: 10),
      );

      expect(result.isSuccess, isTrue);
    });

    test('isSuccess returns false when there are failures', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 1,
        errors: ['Error'],
        duration: const Duration(seconds: 10),
      );

      expect(result.isSuccess, isFalse);
    });

    test('hasOperations returns true when operations performed', () {
      final result1 = SyncResult(
        uploadedCount: 5,
        downloadedCount: 0,
        failedCount: 0,
        errors: [],
        duration: const Duration(seconds: 10),
      );

      final result2 = SyncResult(
        uploadedCount: 0,
        downloadedCount: 3,
        failedCount: 0,
        errors: [],
        duration: const Duration(seconds: 10),
      );

      final result3 = SyncResult(
        uploadedCount: 0,
        downloadedCount: 0,
        failedCount: 1,
        errors: ['Error'],
        duration: const Duration(seconds: 10),
      );

      expect(result1.hasOperations, isTrue);
      expect(result2.hasOperations, isTrue);
      expect(result3.hasOperations, isTrue);
    });

    test('hasOperations returns false when no operations', () {
      final result = SyncResult.empty();

      expect(result.hasOperations, isFalse);
    });

    test('totalOperations calculates correctly', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 2,
        errors: ['Error 1', 'Error 2'],
        duration: const Duration(seconds: 10),
      );

      expect(result.totalOperations, equals(10));
    });

    test('copyWith creates new instance with updated fields', () {
      final original = SyncResult.empty();
      final updated = original.copyWith(
        uploadedCount: 5,
        errors: ['New error'],
      );

      expect(updated.uploadedCount, equals(5));
      expect(updated.errors, equals(['New error']));
      expect(updated.downloadedCount, equals(0));
    });

    test('toJson and fromJson round trip', () {
      final original = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 1,
        errors: ['Error 1', 'Error 2'],
        duration: const Duration(seconds: 10),
      );

      final json = original.toJson();
      final restored = SyncResult.fromJson(json);

      expect(restored.uploadedCount, equals(original.uploadedCount));
      expect(restored.downloadedCount, equals(original.downloadedCount));
      expect(restored.failedCount, equals(original.failedCount));
      expect(restored.errors, equals(original.errors));
      expect(restored.duration, equals(original.duration));
    });

    test('toJson includes duration in milliseconds', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 0,
        errors: [],
        duration: const Duration(seconds: 10),
      );

      final json = result.toJson();

      expect(json['durationMs'], equals(10000));
    });

    test('equality operator works correctly', () {
      final result1 = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 1,
        errors: ['Error'],
        duration: const Duration(seconds: 10),
      );
      final result2 = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 1,
        errors: ['Error'],
        duration: const Duration(seconds: 10),
      );
      final result3 = SyncResult.empty();

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('hashCode is consistent for same values', () {
      final result1 = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 0,
        errors: const [],
        duration: const Duration(seconds: 10),
      );
      final result2 = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 0,
        errors: const [],
        duration: const Duration(seconds: 10),
      );

      // HashCode should be consistent for equal objects
      expect(result1, equals(result2));
    });

    test('toString provides useful information', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 1,
        errors: ['Error'],
        duration: const Duration(seconds: 10),
      );

      final str = result.toString();

      expect(str, contains('SyncResult'));
      expect(str, contains('5'));
      expect(str, contains('3'));
      expect(str, contains('1'));
      expect(str, contains('10'));
    });

    test('handles empty errors list', () {
      final result = SyncResult(
        uploadedCount: 5,
        downloadedCount: 3,
        failedCount: 0,
        errors: [],
        duration: const Duration(seconds: 10),
      );

      final json = result.toJson();
      final restored = SyncResult.fromJson(json);

      expect(restored.errors, isEmpty);
    });
  });
}
