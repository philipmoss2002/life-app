import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

// Test for operation consolidation functionality
// This validates Requirements 10.3: "WHEN multiple operations are queued for the same document, THE system SHALL consolidate them efficiently"

class TestDocument {
  final String id;
  final String userId;
  final String title;
  final int version;
  final DateTime lastModified;

  TestDocument({
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
    return TestDocument(
      id: id,
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
      id: '${type}_${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      documentId: documentId,
      type: type,
      queuedAt: DateTime.now(),
      operationData: operationData,
      priority: priority,
    );

    _operations.add(operation);
  }

  List<TestQueuedOperation> getOperationsForDocument(String documentId) {
    return _operations.where((op) => op.documentId == documentId).toList();
  }

  int get totalOperations => _operations.length;

  // Simulate consolidation logic
  int consolidateOperations() {
    final originalCount = _operations.length;
    final documentGroups = <String, List<TestQueuedOperation>>{};

    // Group operations by document
    for (final operation in _operations) {
      documentGroups.putIfAbsent(operation.documentId, () => []).add(operation);
    }

    final consolidatedOperations = <TestQueuedOperation>[];

    // Process each document group for consolidation
    for (final entry in documentGroups.entries) {
      final operations = entry.value;

      if (operations.length == 1) {
        consolidatedOperations.addAll(operations);
        continue;
      }

      // Sort by queue time
      operations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      // Consolidation logic
      TestQueuedOperation? consolidatedOp;
      final fileOps = <TestQueuedOperation>[];

      for (final op in operations) {
        if (op.type == 'delete') {
          // Delete cancels all previous operations
          consolidatedOp = op;
          fileOps.clear();
        } else if (op.type == 'upload' || op.type == 'update') {
          if (consolidatedOp == null || consolidatedOp.type == 'delete') {
            consolidatedOp = op;
          } else {
            // Merge with existing document operation
            final mergedData =
                Map<String, dynamic>.from(consolidatedOp.operationData);
            mergedData.addAll(op.operationData);

            consolidatedOp = TestQueuedOperation(
              id: consolidatedOp.id,
              documentId: consolidatedOp.documentId,
              type: consolidatedOp.type == 'upload' ? 'upload' : op.type,
              queuedAt: consolidatedOp.queuedAt,
              operationData: mergedData,
              priority: max(consolidatedOp.priority, op.priority),
            );
          }
        } else {
          // File operations
          fileOps.add(op);
        }
      }

      if (consolidatedOp != null) {
        consolidatedOperations.add(consolidatedOp);
      }
      consolidatedOperations.addAll(fileOps);
    }

    // Replace operations with consolidated ones
    _operations.clear();
    _operations.addAll(consolidatedOperations);

    return originalCount - _operations.length;
  }
}

void main() {
  group('Operation Consolidation Tests', () {
    test('should consolidate multiple updates for same document', () {
      final queue = TestConsolidationQueue();
      final document = TestDocument(
        id: 'doc1',
        userId: 'user1',
        title: 'Original Title',
        version: 1,
        lastModified: DateTime.now(),
      );

      // Queue multiple update operations
      queue.queueOperation(
        documentId: 'doc1',
        type: 'update',
        operationData: {
          'document': document.copyWith(title: 'Title v1').toJson()
        },
      );

      queue.queueOperation(
        documentId: 'doc1',
        type: 'update',
        operationData: {
          'document': document.copyWith(title: 'Title v2').toJson()
        },
      );

      queue.queueOperation(
        documentId: 'doc1',
        type: 'update',
        operationData: {
          'document': document.copyWith(title: 'Title v3').toJson()
        },
      );

      expect(queue.totalOperations, equals(3));

      // Consolidate operations
      final consolidatedCount = queue.consolidateOperations();

      // Should consolidate 3 operations into 1
      expect(consolidatedCount, equals(2));
      expect(queue.totalOperations, equals(1));

      // Verify the consolidated operation has the latest data
      final operations = queue.getOperationsForDocument('doc1');
      expect(operations.length, equals(1));
      expect(operations.first.type, equals('update'));
    });

    test('should consolidate upload followed by updates', () {
      final queue = TestConsolidationQueue();
      final document = TestDocument(
        id: 'doc2',
        userId: 'user1',
        title: 'Original Title',
        version: 1,
        lastModified: DateTime.now(),
      );

      // Queue upload then updates
      queue.queueOperation(
        documentId: 'doc2',
        type: 'upload',
        operationData: {'document': document.toJson()},
      );

      queue.queueOperation(
        documentId: 'doc2',
        type: 'update',
        operationData: {
          'document': document.copyWith(title: 'Updated Title').toJson()
        },
      );

      expect(queue.totalOperations, equals(2));

      // Consolidate operations
      final consolidatedCount = queue.consolidateOperations();

      // Should consolidate 2 operations into 1
      expect(consolidatedCount, equals(1));
      expect(queue.totalOperations, equals(1));

      // Verify the consolidated operation is still an upload (initial creation)
      final operations = queue.getOperationsForDocument('doc2');
      expect(operations.length, equals(1));
      expect(operations.first.type, equals('upload'));
    });

    test('should handle delete operations canceling previous operations', () {
      final queue = TestConsolidationQueue();
      final document = TestDocument(
        id: 'doc3',
        userId: 'user1',
        title: 'Original Title',
        version: 1,
        lastModified: DateTime.now(),
      );

      // Queue multiple operations then delete
      queue.queueOperation(
        documentId: 'doc3',
        type: 'upload',
        operationData: {'document': document.toJson()},
      );

      queue.queueOperation(
        documentId: 'doc3',
        type: 'update',
        operationData: {
          'document': document.copyWith(title: 'Updated').toJson()
        },
      );

      queue.queueOperation(
        documentId: 'doc3',
        type: 'delete',
        operationData: {'document': document.toJson()},
      );

      expect(queue.totalOperations, equals(3));

      // Consolidate operations
      final consolidatedCount = queue.consolidateOperations();

      // Should consolidate to just the delete operation
      expect(consolidatedCount, equals(2));
      expect(queue.totalOperations, equals(1));

      // Verify only delete operation remains
      final operations = queue.getOperationsForDocument('doc3');
      expect(operations.length, equals(1));
      expect(operations.first.type, equals('delete'));
    });

    test('should preserve operations for different documents', () {
      final queue = TestConsolidationQueue();

      // Queue operations for different documents
      queue.queueOperation(
        documentId: 'doc1',
        type: 'upload',
        operationData: {
          'document': {'id': 'doc1', 'title': 'Doc 1'}
        },
      );

      queue.queueOperation(
        documentId: 'doc2',
        type: 'upload',
        operationData: {
          'document': {'id': 'doc2', 'title': 'Doc 2'}
        },
      );

      queue.queueOperation(
        documentId: 'doc1',
        type: 'update',
        operationData: {
          'document': {'id': 'doc1', 'title': 'Doc 1 Updated'}
        },
      );

      expect(queue.totalOperations, equals(3));

      // Consolidate operations
      final consolidatedCount = queue.consolidateOperations();

      // Should consolidate doc1 operations but preserve doc2
      expect(consolidatedCount, equals(1));
      expect(queue.totalOperations, equals(2));

      // Verify both documents have operations
      expect(queue.getOperationsForDocument('doc1').length, equals(1));
      expect(queue.getOperationsForDocument('doc2').length, equals(1));
    });

    test('should handle mixed operation types efficiently', () {
      final queue = TestConsolidationQueue();

      // Queue mixed operations for same document
      queue.queueOperation(
        documentId: 'doc4',
        type: 'upload',
        operationData: {
          'document': {'id': 'doc4', 'title': 'Original'}
        },
      );

      queue.queueOperation(
        documentId: 'doc4',
        type: 'fileUpload',
        operationData: {'filePath': '/path/to/file1.pdf'},
      );

      queue.queueOperation(
        documentId: 'doc4',
        type: 'update',
        operationData: {
          'document': {'id': 'doc4', 'title': 'Updated'}
        },
      );

      queue.queueOperation(
        documentId: 'doc4',
        type: 'fileUpload',
        operationData: {'filePath': '/path/to/file2.pdf'},
      );

      expect(queue.totalOperations, equals(4));

      // Consolidate operations
      final consolidatedCount = queue.consolidateOperations();

      // Should consolidate document operations but preserve file operations
      expect(consolidatedCount, equals(1)); // upload + update = 1 upload
      expect(queue.totalOperations, equals(3)); // 1 document op + 2 file ops

      final operations = queue.getOperationsForDocument('doc4');
      expect(operations.length, equals(3));

      // Should have 1 document operation and 2 file operations
      final documentOps = operations
          .where((op) => op.type == 'upload' || op.type == 'update')
          .length;
      final fileOps = operations.where((op) => op.type == 'fileUpload').length;

      expect(documentOps, equals(1));
      expect(fileOps, equals(2));
    });
  });
}
