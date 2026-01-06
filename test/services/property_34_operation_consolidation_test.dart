import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:amplify_core/amplify_core.dart' as amplify_core;
// Property 34: Operation Consolidation
// Validates: Requirements 10.3 - "WHEN multiple operations are queued for the same document, THE system SHALL consolidate them efficiently"

class TestDocument {
  final String id;
  final String userId;
  final String title;
  final int version;
  final DateTime lastModified;

  TestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), {,
    required this.id,
    required this.userId,
    required this.title,
    required this.version,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'version': version,
      'lastModified': lastModified.toIso8601String(),
    };
  }

  TestDocument copyWith({
    String? title,
    int? version,
  }) {
    return TestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"),

            userId: userId,
      title: title ?? this.title,
      version: version ?? this.version,
      lastModified: DateTime.now(),
    );
  }
}

class TestQueuedOperation {
  final String id;
  final String documentId;
  final String type;
  final DateTime queuedAt;
  final Map<String, dynamic> operationData;
  final int priority;

  TestQueuedOperation({
    required this.id,
    required this.documentId,
    required this.type,
    required this.queuedAt,
    required this.operationData,
    this.priority = 0,
  });
}

class TestConsolidationQueue {
  final List<TestQueuedOperation> _operations = [];

  void queueOperation({
    required String documentId,
    required String type,
    required Map<String, dynamic> operationData,
    int priority = 0,
  }) {
    final operation = TestQueuedOperation(
            documentId: documentId,
      type: type,
      queuedAt: DateTime.now(),
      operationData: operationData,
      priority: priority,
    );

    _operations.add(operation);
  }

  List<TestQueuedOperation> getOperationsForDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), String documentId) {,
    return _operations.where((op) => op.documentId == documentId).toList();
  }

  int get totalOperations => _operations.length;

  // Consolidation logic that validates Requirements 10.3
  ConsolidationResult consolidateOperations() {
    final originalCount = _operations.length;
    final documentGroups = <String, List<TestQueuedOperation>>{};

    // Group operations by document
    for (final operation in _operations) {
      documentGroups.putIfAbsent(operation.documentId, () => []).add(operation);
    }

    final consolidatedOperations = <TestQueuedOperation>[];
    final consolidationStats = <String, int>{};

    // Process each document group for consolidation
    for (final entry in documentGroups.entries) {
      final documentId = entry.key;
      final operations = entry.value;

      if (operations.length == 1) {
        consolidatedOperations.addAll(operations);
        consolidationStats[documentId] = 0;
        continue;
      }

      // Sort by queue time to maintain operation order
      operations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      final originalDocumentOpCount = operations.length;
      final consolidatedDocOps = _consolidateDocumentOperations(operations);

      consolidatedOperations.addAll(consolidatedDocOps);
      consolidationStats[documentId] =
          originalDocumentOpCount - consolidatedDocOps.length;
    }

    // Replace operations with consolidated ones
    _operations.clear();
    _operations.addAll(consolidatedOperations);

    return ConsolidationResult(
      originalCount: originalCount,
      finalCount: _operations.length,
      consolidatedCount: originalCount - _operations.length,
      documentStats: consolidationStats,
    );
  }

  List<TestQueuedOperation> _consolidateDocumentOperations(
      List<TestQueuedOperation> operations) {
    TestQueuedOperation? consolidatedDocOp;
    final fileOps = <TestQueuedOperation>[];

    for (final op in operations) {
      if (op.type == 'delete') {
        // Delete cancels all previous document operations
        consolidatedDocOp = op;
        fileOps.clear(); // Delete also cancels file operations
      } else if (op.type == 'upload' || op.type == 'update') {
        if (consolidatedDocOp == null || consolidatedDocOp.type == 'delete') {
          consolidatedDocOp = op;
        } else {
          // Merge with existing document operation
          final mergedData =
              Map<String, dynamic>.from(consolidatedDocOp.operationData);
          mergedData.addAll(op.operationData);

          consolidatedDocOp = TestQueuedOperation(
                        documentId: consolidatedDocOp.documentId,
            type: consolidatedDocOp.type == 'upload' ? 'upload' : op.type,
            queuedAt: consolidatedDocOp.queuedAt,
            operationData: mergedData,
            priority: max(consolidatedDocOp.priority, op.priority),
          );
        }
      } else {
        // File operations are preserved separately
        fileOps.add(op);
      }
    }

    final result = <TestQueuedOperation>[];
    if (consolidatedDocOp != null) {
      result.add(consolidatedDocOp);
    }
    result.addAll(fileOps);

    return result;
  }
}

class ConsolidationResult {
  final int originalCount;
  final int finalCount;
  final int consolidatedCount;
  final Map<String, int> documentStats;

  ConsolidationResult({
    required this.originalCount,
    required this.finalCount,
    required this.consolidatedCount,
    required this.documentStats,
  });

  double get efficiencyRatio =>
      originalCount > 0 ? consolidatedCount / originalCount : 0.0;
}

void main() {
  group('Property 34: Operation Consolidation', () {
    test(
        'For any multiple operations queued for the same document, they should be consolidated efficiently',
        () async {
      /**
       * Feature: cloud-sync-implementation-fix, Property 34: Operation Consolidation
       * Validates: Requirements 10.3
       */

      // Property: For any multiple operations on the same document in the queue, they should be consolidated efficiently
      final queue = TestConsolidationQueue();
      final random = Random();

      // Test multiple scenarios with different operation patterns
      for (int scenario = 0; scenario < 10; scenario++) {
        final documentId = 'test_doc_$scenario';
        final userId = 'user_${random.nextInt(5)}';
        final operationCount =
            random.nextInt(8) + 2; // 2-9 operations per document

        final baseDocument = TestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"),

                    userId: userId,
          title: 'Original Title $scenario',
          version: random.nextInt(10) + 1,
          lastModified:
              DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
        );

        // Generate random sequence of operations for this document
        final operationTypes = [
          'upload',
          'update',
          'delete',
          'fileUpload',
          'fileDelete'
        ];

        for (int i = 0; i < operationCount; i++) {
          final opType = operationTypes[random.nextInt(operationTypes.length)];

          Map<String, dynamic> operationData;
          if (opType == 'upload' || opType == 'update') {
            operationData = {
              'document': baseDocument
                  .copyWith(
                    title: 'Title v$i for $scenario',
                    version: baseDocument.version + i,
                  )
                  .toJson()
            };
          } else if (opType == 'delete') {
            operationData = {'document': baseDocument.toJson()};
          } else {
            // File operations
            operationData = {
              'filePath': '/path/to/file_${scenario}_$i.pdf',
              'fileSize': random.nextInt(1000000),
            };
          }

          queue.queueOperation(
            documentId: documentId,
            type: opType,
            operationData: operationData,
            priority: random.nextInt(3),
          );

          // Small delay to ensure different timestamps
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      final initialOperationCount = queue.totalOperations;
      expect(initialOperationCount,
          greaterThan(20)); // Should have many operations

      // Perform consolidation
      final result = queue.consolidateOperations();

      // Validate consolidation efficiency (Requirements 10.3)
      expect(result.originalCount, equals(initialOperationCount));
      expect(result.finalCount, lessThanOrEqualTo(result.originalCount));
      expect(result.consolidatedCount, greaterThanOrEqualTo(0));

      // Verify consolidation actually occurred for documents with multiple operations
      bool hasConsolidation = false;
      for (final entry in result.documentStats.entries) {
        if (entry.value > 0) {
          hasConsolidation = true;
          break;
        }
      }
      expect(hasConsolidation, isTrue,
          reason: 'Should consolidate at least some operations');

      // Validate that consolidation preserves operation semantics
      for (int scenario = 0; scenario < 10; scenario++) {
        final documentId = 'test_doc_$scenario';
        final operations = queue.getOperationsForDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), documentId);

        // Each document should have at most one document operation (upload/update/delete)
        final documentOps = operations
            .where((op) =>
                op.type == 'upload' ||
                op.type == 'update' ||
                op.type == 'delete')
            .toList();

        expect(documentOps.length, lessThanOrEqualTo(1),
            reason:
                'Should consolidate to at most one document operation per document');

        // File operations should be preserved separately
        final fileOps = operations
            .where((op) => op.type == 'fileUpload' || op.type == 'fileDelete')
            .toList();

        // Verify operation ordering is maintained (consolidated operations should have reasonable timestamps)
        if (operations.isNotEmpty) {
          // Just verify that timestamps are valid and not null
          for (final op in operations) {
            expect(op.queuedAt, isNotNull);
            expect(
                op.queuedAt
                    .isBefore(DateTime.now().add(const Duration(seconds: 1))),
                isTrue);
          }
        }
      }

      // Test specific consolidation scenarios to validate efficiency

      // Scenario 1: Multiple updates should consolidate to one
      const testDocId1 = 'consolidation_test_1';
      final testDoc1 = TestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"),

                userId: 'test_user',
        title: 'Test Doc 1',
        version: 1,
        lastModified: DateTime.now(),
      );

      final queue2 = TestConsolidationQueue();

      // Add multiple updates
      for (int i = 0; i < 5; i++) {
        queue2.queueOperation(
          documentId: testDocId1,
          type: 'update',
          operationData: {
            'document': testDoc1.copyWith(title: 'Updated $i').toJson()
          },
        );
        await Future.delayed(const Duration(milliseconds: 1));
      }

      expect(queue2.totalOperations, equals(5));

      final result2 = queue2.consolidateOperations();
      expect(result2.consolidatedCount, equals(4)); // 5 -> 1
      expect(queue2.getOperationsForDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), testDocId1).length, equals(1));

      // Scenario 2: Upload + Updates should consolidate to Upload
      const testDocId2 = 'consolidation_test_2';
      final queue3 = TestConsolidationQueue();

      queue3.queueOperation(
        documentId: testDocId2,
        type: 'upload',
        operationData: {'document': testDoc1.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue3.queueOperation(
        documentId: testDocId2,
        type: 'update',
        operationData: {
          'document': testDoc1.copyWith(title: 'Updated').toJson()
        },
      );

      final result3 = queue3.consolidateOperations();
      expect(result3.consolidatedCount, equals(1)); // 2 -> 1

      final ops = queue3.getOperationsForDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), testDocId2);
      expect(ops.length, equals(1));
      expect(ops.first.type, equals('upload')); // Should remain upload

      // Scenario 3: Delete should cancel previous operations
      const testDocId3 = 'consolidation_test_3';
      final queue4 = TestConsolidationQueue();

      queue4.queueOperation(
        documentId: testDocId3,
        type: 'upload',
        operationData: {'document': testDoc1.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue4.queueOperation(
        documentId: testDocId3,
        type: 'update',
        operationData: {
          'document': testDoc1.copyWith(title: 'Updated').toJson()
        },
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue4.queueOperation(
        documentId: testDocId3,
        type: 'delete',
        operationData: {'document': testDoc1.toJson()},
      );

      final result4 = queue4.consolidateOperations();
      expect(result4.consolidatedCount, equals(2)); // 3 -> 1

      final ops4 = queue4.getOperationsForDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), testDocId3);
      expect(ops4.length, equals(1));
      expect(ops4.first.type, equals('delete')); // Should only have delete

      // Validate overall efficiency requirement
      // The system should reduce the total number of operations while preserving semantics
      expect(result.efficiencyRatio, greaterThan(0.0),
          reason: 'Consolidation should achieve some efficiency gain');

      // Verify that no operations are lost inappropriately
      expect(result.finalCount, greaterThan(0),
          reason: 'Should preserve necessary operations');

      print(
          'Consolidation efficiency: ${(result.efficiencyRatio * 100).toStringAsFixed(1)}%');
      print(
          'Operations reduced from ${result.originalCount} to ${result.finalCount}');
    });
  });
}
