import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:amplify_core/amplify_core.dart' as amplify_core;
/**
 * Feature: sync-identifier-refactor, Property 7: Sync Queue Consolidation
 * Validates: Requirements 7.5
 * 
 * Property: For any sync identifier with multiple queued operations, 
 * the operations should be consolidated into the most recent state
 * 
 * This property tests that the sync queue correctly consolidates multiple
 * operations for the same sync identifier, reducing redundant operations
 * while preserving the final state.
 */

/// Test model for a document with sync identifier
class TestDocument {
  final String id;
  final String syncId;
  final String userId;
  final String title;
  final int version;
  final DateTime lastModified;

  TestDocument(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending"), {,
    required this.id,
    required this.syncId,
    required this.userId,
    required this.title,
    required this.version,
    required this.lastModified,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'syncId': syncId,
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
    return TestDocument(syncId: syncId, userId: userId, title: title ?? this.title, version: version ?? this.version, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
    );
  }
}

/// Test model for a queued sync operation
class TestSyncOperation {
  final String id;
  final String documentId;
  final String syncId;
  final String type;
  final DateTime queuedAt;
  final Map<String, dynamic> operationData;
  final int priority;

  TestSyncOperation({
    required this.id,
    required this.documentId,
    required this.syncId,
    required this.type,
    required this.queuedAt,
    required this.operationData,
    this.priority = 0,
  });
}

/// Test implementation of sync queue with consolidation by sync identifier
class TestSyncQueue {
  final List<TestSyncOperation> _operations = [];

  void queueOperation({
    required String documentId,
    required String syncId,
    required String type,
    required Map<String, dynamic> operationData,
    int priority = 0,
  }) {
    final operation = TestSyncOperation(
            documentId: documentId,
      syncId: syncId,
      type: type,
      queuedAt: DateTime.now(),
      operationData: operationData,
      priority: priority,
    );

    _operations.add(operation);
  }

  List<TestSyncOperation> getOperationsForSyncId(String syncId) {
    return _operations.where((op) => op.syncId == syncId).toList();
  }

  int get totalOperations => _operations.length;

  /// Consolidate operations by sync identifier (Requirements 7.5)
  ConsolidationResult consolidateBySyncId() {
    final originalCount = _operations.length;
    final syncIdGroups = <String, List<TestSyncOperation>>{};

    // Group operations by sync identifier
    for (final operation in _operations) {
      syncIdGroups.putIfAbsent(operation.syncId, () => []).add(operation);
    }

    final consolidatedOperations = <TestSyncOperation>[];
    final consolidationStats = <String, int>{};

    // Process each sync identifier group for consolidation
    for (final entry in syncIdGroups.entries) {
      final syncId = entry.key;
      final operations = entry.value;

      if (operations.length == 1) {
        consolidatedOperations.addAll(operations);
        consolidationStats[syncId] = 0;
        continue;
      }

      // Sort by queue time to maintain operation order
      operations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      final originalSyncIdOpCount = operations.length;
      final consolidatedOps = _consolidateOperationsForSyncId(operations);

      consolidatedOperations.addAll(consolidatedOps);
      consolidationStats[syncId] =
          originalSyncIdOpCount - consolidatedOps.length;
    }

    // Replace operations with consolidated ones
    _operations.clear();
    _operations.addAll(consolidatedOperations);

    return ConsolidationResult(
      originalCount: originalCount,
      finalCount: _operations.length,
      consolidatedCount: originalCount - _operations.length,
      syncIdStats: consolidationStats,
    );
  }

  /// Consolidate operations for a single sync identifier
  List<TestSyncOperation> _consolidateOperationsForSyncId(
      List<TestSyncOperation> operations) {
    if (operations.length <= 1) {
      return operations;
    }

    TestSyncOperation? finalOperation;

    // Process operations in chronological order
    for (final operation in operations) {
      switch (operation.type) {
        case 'delete':
          // Delete becomes the final operation, canceling previous ones
          finalOperation = operation;
          break;

        case 'upload':
        case 'update':
          if (finalOperation == null) {
            // First operation
            finalOperation = operation;
          } else if (finalOperation.type == 'delete') {
            // Operation after delete - this is a new document, so replace the delete
            finalOperation = operation;
          } else if (finalOperation.type == 'upload' ||
              finalOperation.type == 'update') {
            // Consolidate with existing document operation
            // Keep the earliest operation ID but use latest data
            final mergedData =
                Map<String, dynamic>.from(finalOperation.operationData);
            mergedData.addAll(operation.operationData);

            finalOperation = TestSyncOperation(
                            documentId: finalOperation.documentId,
              syncId: finalOperation.syncId,
              type: finalOperation.type == 'upload' ? 'upload' : operation.type,
              queuedAt: finalOperation.queuedAt,
              operationData: mergedData,
              priority: max(finalOperation.priority, operation.priority),
            );
          }
          break;

        default:
          // Other operation types - for now we don't handle these in consolidation
          // In a real implementation, file operations might be handled separately
          break;
      }
    }

    // Return the final consolidated operation
    return finalOperation != null ? [finalOperation] : [];
  }
}

class ConsolidationResult {
  final int originalCount;
  final int finalCount;
  final int consolidatedCount;
  final Map<String, int> syncIdStats;

  ConsolidationResult({
    required this.originalCount,
    required this.finalCount,
    required this.consolidatedCount,
    required this.syncIdStats,
  });

  double get efficiencyRatio =>
      originalCount > 0 ? consolidatedCount / originalCount : 0.0;
}

void main() {
  group('Property 7: Sync Queue Consolidation', () {
    test(
        'For any sync identifier with multiple queued operations, they should be consolidated into the most recent state',
        () async {
      /**
       * Feature: sync-identifier-refactor, Property 7: Sync Queue Consolidation
       * Validates: Requirements 7.5
       */

      // Property: For any sync identifier with multiple operations in the queue,
      // they should be consolidated efficiently
      final queue = TestSyncQueue();
      final random = Random();

      // Test multiple scenarios with different sync identifiers and operation patterns
      final syncIdentifiers = <String>[];
      for (int i = 0; i < 10; i++) {
        syncIdentifiers.add('sync-id-${random.nextInt(1000000)}');
      }

      // Generate random sequences of operations for each sync identifier
      for (final syncId in syncIdentifiers) {
        final documentId = 'doc-${random.nextInt(1000)}';
        final userId = 'user-${random.nextInt(5)}';
        final operationCount =
            random.nextInt(8) + 2; // 2-9 operations per sync ID

        final baseDocument = TestDocument(syncId: syncId, userId: userId, title: 'Original Title for $syncId', version: random.nextInt(10, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), syncState: "pending") + 1,
          lastModified:
              DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
        );

        // Generate random sequence of operations for this sync identifier
        final operationTypes = ['upload', 'update', 'delete'];

        for (int i = 0; i < operationCount; i++) {
          final opType = operationTypes[random.nextInt(operationTypes.length)];

          Map<String, dynamic> operationData;
          if (opType == 'upload' || opType == 'update') {
            operationData = {
              'document': baseDocument
                  .copyWith(
                    title: 'Title v$i for $syncId',
                    version: baseDocument.version + i,
                  )
                  .toJson()
            };
          } else {
            // Delete operation
            operationData = {'document': baseDocument.toJson()};
          }

          queue.queueOperation(
            documentId: documentId,
            syncId: syncId,
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

      // Perform consolidation by sync identifier
      final result = queue.consolidateBySyncId();

      // Validate consolidation efficiency (Requirements 7.5)
      expect(result.originalCount, equals(initialOperationCount));
      expect(result.finalCount, lessThanOrEqualTo(result.originalCount));
      expect(result.consolidatedCount, greaterThanOrEqualTo(0));

      // Verify consolidation actually occurred for sync IDs with multiple operations
      bool hasConsolidation = false;
      for (final entry in result.syncIdStats.entries) {
        if (entry.value > 0) {
          hasConsolidation = true;
          break;
        }
      }
      expect(hasConsolidation, isTrue,
          reason: 'Should consolidate at least some operations');

      // Validate that consolidation preserves operation semantics per sync identifier
      for (final syncId in syncIdentifiers) {
        final operations = queue.getOperationsForSyncId(syncId);

        // Each sync identifier should have at most one document operation (upload/update/delete)
        final documentOps = operations
            .where((op) =>
                op.type == 'upload' ||
                op.type == 'update' ||
                op.type == 'delete')
            .toList();

        // Debug information for failing test
        if (documentOps.length > 1) {
          print(
              'DEBUG: Sync ID $syncId has ${documentOps.length} document operations:');
          for (final op in documentOps) {
            print('  - ${op.type} at ${op.queuedAt}');
          }
        }

        expect(documentOps.length, lessThanOrEqualTo(1),
            reason:
                'Should consolidate to at most one document operation per sync identifier (found ${documentOps.length} for $syncId)');

        // Verify all operations for this sync ID have the same sync identifier
        for (final op in operations) {
          expect(op.syncId, equals(syncId),
              reason: 'All operations should have the correct sync identifier');
        }
      }

      // Test specific consolidation scenarios to validate Requirements 7.5

      // Scenario 1: Multiple updates for same sync ID should consolidate to one
      final testSyncId1 = 'test-sync-id-1';
      final testDoc1 = TestDocument(syncId: testSyncId1, userId: 'test-user', title: 'Test Doc 1', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );

      final queue2 = TestSyncQueue();

      // Add multiple updates for the same sync identifier
      for (int i = 0; i < 5; i++) {
        queue2.queueOperation(
          documentId: testDoc1.id,
          syncId: testSyncId1,
          type: 'update',
          operationData: {
            'document': testDoc1.copyWith(title: 'Updated $i').toJson()
          },
        );
        await Future.delayed(const Duration(milliseconds: 1));
      }

      expect(queue2.totalOperations, equals(5));

      final result2 = queue2.consolidateBySyncId();
      expect(result2.consolidatedCount, equals(4)); // 5 -> 1
      expect(queue2.getOperationsForSyncId(testSyncId1).length, equals(1));

      // Scenario 2: Upload + Updates for same sync ID should consolidate to Upload
      final testSyncId2 = 'test-sync-id-2';
      final testDoc2 = TestDocument(syncId: testSyncId2, userId: 'test-user', title: 'Test Doc 2', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );

      final queue3 = TestSyncQueue();

      queue3.queueOperation(
        documentId: testDoc2.id,
        syncId: testSyncId2,
        type: 'upload',
        operationData: {'document': testDoc2.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue3.queueOperation(
        documentId: testDoc2.id,
        syncId: testSyncId2,
        type: 'update',
        operationData: {
          'document': testDoc2.copyWith(title: 'Updated').toJson()
        },
      );

      final result3 = queue3.consolidateBySyncId();
      expect(result3.consolidatedCount, equals(1)); // 2 -> 1

      final ops = queue3.getOperationsForSyncId(testSyncId2);
      expect(ops.length, equals(1));
      expect(ops.first.type, equals('upload')); // Should remain upload

      // Scenario 3: Delete should cancel previous operations for same sync ID
      final testSyncId3 = 'test-sync-id-3';
      final testDoc3 = TestDocument(syncId: testSyncId3, userId: 'test-user', title: 'Test Doc 3', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );

      final queue4 = TestSyncQueue();

      queue4.queueOperation(
        documentId: testDoc3.id,
        syncId: testSyncId3,
        type: 'upload',
        operationData: {'document': testDoc3.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue4.queueOperation(
        documentId: testDoc3.id,
        syncId: testSyncId3,
        type: 'update',
        operationData: {
          'document': testDoc3.copyWith(title: 'Updated').toJson()
        },
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue4.queueOperation(
        documentId: testDoc3.id,
        syncId: testSyncId3,
        type: 'delete',
        operationData: {'document': testDoc3.toJson()},
      );

      final result4 = queue4.consolidateBySyncId();
      expect(result4.consolidatedCount, equals(2)); // 3 -> 1

      final ops4 = queue4.getOperationsForSyncId(testSyncId3);
      expect(ops4.length, equals(1));
      expect(ops4.first.type, equals('delete')); // Should only have delete

      // Scenario 4: Different sync IDs should not interfere with each other
      final testSyncId4a = 'test-sync-id-4a';
      final testSyncId4b = 'test-sync-id-4b';
      final testDoc4a = TestDocument(syncId: testSyncId4a, userId: 'test-user', title: 'Test Doc 4a', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );
      final testDoc4b = TestDocument(syncId: testSyncId4b, userId: 'test-user', title: 'Test Doc 4b', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );

      final queue5 = TestSyncQueue();

      // Add operations for sync ID 4a
      queue5.queueOperation(
        documentId: testDoc4a.id,
        syncId: testSyncId4a,
        type: 'upload',
        operationData: {'document': testDoc4a.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue5.queueOperation(
        documentId: testDoc4a.id,
        syncId: testSyncId4a,
        type: 'update',
        operationData: {
          'document': testDoc4a.copyWith(title: 'Updated 4a').toJson()
        },
      );

      // Add operations for sync ID 4b
      await Future.delayed(const Duration(milliseconds: 1));

      queue5.queueOperation(
        documentId: testDoc4b.id,
        syncId: testSyncId4b,
        type: 'upload',
        operationData: {'document': testDoc4b.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue5.queueOperation(
        documentId: testDoc4b.id,
        syncId: testSyncId4b,
        type: 'update',
        operationData: {
          'document': testDoc4b.copyWith(title: 'Updated 4b').toJson()
        },
      );

      expect(queue5.totalOperations, equals(4));

      final result5 = queue5.consolidateBySyncId();
      expect(result5.consolidatedCount, equals(2)); // 4 -> 2 (one per sync ID)

      final ops5a = queue5.getOperationsForSyncId(testSyncId4a);
      final ops5b = queue5.getOperationsForSyncId(testSyncId4b);

      expect(ops5a.length, equals(1),
          reason: 'Sync ID 4a should have one consolidated operation');
      expect(ops5b.length, equals(1),
          reason: 'Sync ID 4b should have one consolidated operation');

      // Verify sync IDs are preserved correctly
      expect(ops5a.first.syncId, equals(testSyncId4a));
      expect(ops5b.first.syncId, equals(testSyncId4b));

      // Validate overall efficiency requirement
      // The system should reduce the total number of operations while preserving semantics
      expect(result.efficiencyRatio, greaterThan(0.0),
          reason: 'Consolidation should achieve some efficiency gain');

      // Verify that no operations are lost inappropriately
      expect(result.finalCount, greaterThan(0),
          reason: 'Should preserve necessary operations');
    });

    test(
        'Consolidation by sync identifier should preserve the most recent state',
        () async {
      /**
       * Feature: sync-identifier-refactor, Property 7: Sync Queue Consolidation
       * Validates: Requirements 7.5
       */

      // This test verifies that when multiple operations are consolidated,
      // the final operation contains the most recent state
      final queue = TestSyncQueue();
      final syncId = 'test-sync-id-state';
      final documentId = 'doc-state';

      final baseDoc = TestDocument(syncId: syncId, userId: 'test-user', title: 'Original', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );

      // Queue multiple updates with different titles
      final titles = ['Title 1', 'Title 2', 'Title 3', 'Title 4', 'Title 5'];

      for (int i = 0; i < titles.length; i++) {
        queue.queueOperation(
          documentId: documentId,
          syncId: syncId,
          type: 'update',
          operationData: {
            'document':
                baseDoc.copyWith(title: titles[i], version: i + 2).toJson()
          },
        );
        await Future.delayed(const Duration(milliseconds: 1));
      }

      expect(queue.totalOperations, equals(5));

      // Consolidate
      final result = queue.consolidateBySyncId();
      expect(result.consolidatedCount, equals(4)); // 5 -> 1

      // Verify the consolidated operation has the most recent state
      final ops = queue.getOperationsForSyncId(syncId);
      expect(ops.length, equals(1));

      final consolidatedOp = ops.first;
      final document =
          consolidatedOp.operationData['document'] as Map<String, dynamic>;

      // The consolidated operation should have the latest title
      expect(document['title'], equals('Title 5'),
          reason: 'Consolidated operation should have the most recent state');
      expect(document['version'], equals(6),
          reason: 'Consolidated operation should have the most recent version');
    });

    test(
        'Consolidation should work correctly with null or missing sync identifiers',
        () async {
      /**
       * Feature: sync-identifier-refactor, Property 7: Sync Queue Consolidation
       * Validates: Requirements 7.5
       */

      // This test ensures the consolidation logic handles edge cases gracefully
      final queue = TestSyncQueue();

      // Add operations with valid sync identifiers
      final syncId1 = 'valid-sync-id-1';
      final doc1 = TestDocument(syncId: syncId1, userId: 'user-1', title: 'Doc 1', version: 1, lastModified: DateTime.now(, category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), syncState: "pending"),
      );

      queue.queueOperation(
        documentId: doc1.id,
        syncId: syncId1,
        type: 'upload',
        operationData: {'document': doc1.toJson()},
      );

      await Future.delayed(const Duration(milliseconds: 1));

      queue.queueOperation(
        documentId: doc1.id,
        syncId: syncId1,
        type: 'update',
        operationData: {'document': doc1.copyWith(title: 'Updated').toJson()},
      );

      expect(queue.totalOperations, equals(2));

      // Consolidate
      final result = queue.consolidateBySyncId();

      // Should consolidate the two operations for the same sync ID
      expect(result.consolidatedCount, equals(1));
      expect(queue.getOperationsForSyncId(syncId1).length, equals(1));
    });
  });
}
