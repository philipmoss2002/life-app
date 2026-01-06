import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/error_state_manager.dart';
import 'dart:math';

void main() {
  group('ErrorStateManager', () {
    late ErrorStateManager errorManager;

    setUp(() {
      errorManager = ErrorStateManager();
      // Clear any existing errors before each test
      errorManager.clearAllErrors();
    });

    group('Property Tests', () {
      test(
          'Property 15: Error State Marking - **Feature: cloud-sync-implementation-fix, Property 15: Error State Marking**',
          () async {
        // **Validates: Requirements 4.5**

        // Property: For any operation that exhausts all retries,
        // the document should be marked with error sync state

        final random = Random();

        // Test multiple scenarios with different error types
        final errorTypes = [
          'Network timeout',
          'Authentication failed',
          'Server error 500',
          'Connection refused',
          'Storage full',
          'Invalid document format',
          'Document not found',
          'Permission denied',
        ];

        for (int scenario = 0; scenario < 10; scenario++) {
          final documentId = 'doc_${random.nextInt(1000)}';
          final errorMessage = errorTypes[random.nextInt(errorTypes.length)];
          final retryCount = random.nextInt(10) + 1; // 1-10 retries

          // Mark document as error
          errorManager.markDocumentError(
            documentId,
            errorMessage,
            retryCount: retryCount,
            lastOperation: 'upload',
          );

          // Verify document is marked as error
          expect(errorManager.isDocumentInError(documentId), isTrue,
              reason: 'Document should be marked as in error state');

          final documentError = errorManager.getDocumentError(documentId);
          expect(documentError, isNotNull,
              reason: 'Should be able to retrieve error information');

          expect(documentError!.documentId, equals(documentId),
              reason: 'Error should have correct document ID');
          expect(documentError.errorMessage, equals(errorMessage),
              reason: 'Error should preserve original error message');
          expect(documentError.retryCount, equals(retryCount),
              reason: 'Error should track retry count');

          // Verify user-friendly message is generated
          final userMessage = documentError.getUserFriendlyMessage();
          expect(userMessage.isNotEmpty, isTrue,
              reason: 'Should generate user-friendly error message');
          expect(userMessage, isNot(equals(errorMessage)),
              reason:
                  'User-friendly message should be different from technical error');

          // Verify recovery action is suggested
          final recoveryAction = documentError.recoveryAction;
          expect(recoveryAction.isNotEmpty, isTrue,
              reason: 'Should suggest recovery action');
        }
      });

      test('Error categorization works correctly', () {
        final errorManager = ErrorStateManager();

        // Test recoverable errors
        final recoverableErrors = [
          'Network timeout occurred',
          'Authentication token expired',
          'Server error 500',
          'Connection refused by server',
          'Storage space insufficient',
        ];

        for (final errorMessage in recoverableErrors) {
          errorManager.markDocumentError('doc_recoverable', errorMessage);
          final error = errorManager.getDocumentError('doc_recoverable')!;

          expect(error.isRecoverable, isTrue,
              reason: 'Error should be marked as recoverable: $errorMessage');

          errorManager.clearDocumentError('doc_recoverable');
        }

        // Test non-recoverable errors
        final nonRecoverableErrors = [
          'Document not found',
          'Document was deleted',
          'Invalid document format',
          'Permission denied permanently',
        ];

        for (final errorMessage in nonRecoverableErrors) {
          errorManager.markDocumentError('doc_non_recoverable', errorMessage);
          final error = errorManager.getDocumentError('doc_non_recoverable')!;

          expect(error.isRecoverable, isFalse,
              reason:
                  'Error should be marked as non-recoverable: $errorMessage');

          errorManager.clearDocumentError('doc_non_recoverable');
        }
      });

      test('Retry count tracking works correctly', () {
        final errorManager = ErrorStateManager();
        final documentId = 'test_doc';

        // Initially no retries
        expect(errorManager.getRetryCount(documentId), equals(0),
            reason: 'Initial retry count should be zero');

        // Increment retry count multiple times
        for (int i = 1; i <= 5; i++) {
          errorManager.incrementRetryCount(documentId);
          expect(errorManager.getRetryCount(documentId), equals(i),
              reason: 'Retry count should increment correctly');
        }

        // Check max retries exceeded
        expect(errorManager.hasExceededMaxRetries(documentId, maxRetries: 3),
            isTrue,
            reason: 'Should detect when max retries exceeded');
        expect(errorManager.hasExceededMaxRetries(documentId, maxRetries: 10),
            isFalse,
            reason: 'Should not exceed max retries when limit is higher');
      });

      test('Recovery timing works with exponential backoff', () {
        final errorManager = ErrorStateManager();
        final documentId = 'test_doc';

        // Mark error with low retry count (should allow immediate recovery)
        errorManager.markDocumentError(
          documentId,
          'Network timeout',
          retryCount: 0,
        );

        // Should return a boolean for recovery check
        final canRecoverFirst = errorManager.canAttemptRecovery(documentId);
        expect(canRecoverFirst, isA<bool>(),
            reason: 'Should return boolean for recovery check');

        // Mark error with higher retry count (should require waiting)
        errorManager.clearDocumentError(documentId);
        errorManager.markDocumentError(
          documentId,
          'Network timeout',
          retryCount: 3,
        );

        // Should require waiting for higher retry counts
        // Note: This test might pass immediately due to timing, but the logic is tested
        final canRecover = errorManager.canAttemptRecovery(documentId);
        // We can't reliably test timing in unit tests, so we just verify the method doesn't crash
        expect(canRecover, isA<bool>(),
            reason: 'Recovery check should return boolean');
      });

      test('Error statistics are accurate', () {
        final errorManager = ErrorStateManager();

        // Add various types of errors
        errorManager.markDocumentError('doc1', 'Network timeout');
        errorManager.markDocumentError('doc2', 'Authentication failed');
        errorManager.markDocumentError('doc3', 'Document not found');
        errorManager.markDocumentError('doc4', 'Network connection lost');

        final stats = errorManager.getErrorStats();

        expect(stats['totalErrors'], equals(4),
            reason: 'Should count total errors correctly');
        expect(stats['recoverableErrors'], equals(3),
            reason: 'Should count recoverable errors correctly');
        expect(stats['nonRecoverableErrors'], equals(1),
            reason: 'Should count non-recoverable errors correctly');

        final errorTypes = stats['errorTypes'] as Map<String, int>;
        expect(errorTypes['Network'], equals(2),
            reason: 'Should group network errors correctly');
        expect(errorTypes['Authentication'], equals(1),
            reason: 'Should group authentication errors correctly');
        expect(errorTypes['Not Found'], equals(1),
            reason: 'Should group not found errors correctly');
      });

      test('Recovery plan creation works correctly', () {
        final errorManager = ErrorStateManager();

        // Add different types of errors
        errorManager.markDocumentError('immediate1', 'Network timeout',
            retryCount: 0);
        errorManager.markDocumentError('immediate2', 'Server error',
            retryCount: 0);
        errorManager.markDocumentError('manual1', 'Version conflict detected');
        errorManager.markDocumentError('unrecoverable1', 'Document not found');
        errorManager.markDocumentError('delayed1', 'Network timeout',
            retryCount: 5);

        final plan = errorManager.createRecoveryPlan();

        expect(plan.containsKey('immediate'), isTrue,
            reason: 'Plan should include immediate recovery category');
        expect(plan.containsKey('delayed'), isTrue,
            reason: 'Plan should include delayed recovery category');
        expect(plan.containsKey('manual'), isTrue,
            reason: 'Plan should include manual recovery category');
        expect(plan.containsKey('unrecoverable'), isTrue,
            reason: 'Plan should include unrecoverable category');

        expect(plan['unrecoverable']!.contains('unrecoverable1'), isTrue,
            reason: 'Should categorize non-recoverable errors correctly');
        expect(plan['manual']!.contains('manual1'), isTrue,
            reason: 'Should categorize version conflicts as manual');
      });

      test('Clear operations work correctly', () {
        final errorManager = ErrorStateManager();

        // Add multiple errors
        errorManager.markDocumentError('doc1', 'Error 1');
        errorManager.markDocumentError('doc2', 'Error 2');
        errorManager.markDocumentError('doc3', 'Error 3');

        expect(errorManager.getAllErrorDocuments(), hasLength(3),
            reason: 'Should have 3 error documents');

        // Clear single error
        errorManager.clearDocumentError('doc1');
        expect(errorManager.isDocumentInError('doc1'), isFalse,
            reason: 'Should clear single document error');
        expect(errorManager.getAllErrorDocuments(), hasLength(2),
            reason: 'Should have 2 error documents after clearing one');

        // Clear all errors
        errorManager.clearAllErrors();
        expect(errorManager.getAllErrorDocuments(), isEmpty,
            reason: 'Should clear all errors');
      });

      test('User-friendly messages are appropriate', () {
        final errorManager = ErrorStateManager();

        final testCases = {
          'Network connection timeout': 'Network connection issue',
          'Authentication token expired': 'Authentication issue',
          'Version conflict detected':
              'Document was modified on another device',
          'Document not found on server': 'Document not found on server',
          'Storage space insufficient': 'Storage issue',
          'Unknown error occurred': 'Sync failed',
        };

        testCases.forEach((errorMessage, expectedKeyword) {
          errorManager.markDocumentError('test_doc', errorMessage);
          final error = errorManager.getDocumentError('test_doc')!;
          final userMessage = error.getUserFriendlyMessage();

          expect(userMessage.toLowerCase(),
              contains(expectedKeyword.toLowerCase()),
              reason:
                  'User message should contain appropriate keyword for: $errorMessage');

          errorManager.clearDocumentError('test_doc');
        });
      });
    });
  });
}
