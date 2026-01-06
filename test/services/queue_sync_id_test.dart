import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import '../../lib/services/offline_sync_queue_service.dart';

import 'package:amplify_core/amplify_core.dart' as amplify_core;
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Queue Sync ID Updates', () {
    late OfflineSyncQueueService queueService;

    setUp(() async {
      queueService = OfflineSyncQueueService();
      await queueService.initialize();
    });

    tearDown(() async {
      await queueService.clearQueue();
      await queueService.dispose();
    });

    test('QueuedSyncOperation should include syncId field', () {
      final operation = QueuedSyncOperation(
                documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        queuedAt: DateTime.now(),
        operationData: {'test': 'data'},
      );

      expect(operation.syncId, equals('sync-123'));
      expect(operation.documentId, equals('doc-123'));
      expect(operation.type, equals(QueuedOperationType.upload));
    });

    test('QueuedSyncOperation copyWith should preserve syncId', () {
      final operation = QueuedSyncOperation(
                documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        queuedAt: DateTime.now(),
        operationData: {'test': 'data'},
      );

      final copied = operation.copyWith(retryCount: 1);

      expect(copied.syncId, equals('sync-123'));
      expect(copied.documentId, equals('doc-123'));
      expect(copied.retryCount, equals(1));
      expect(copied.type, equals(QueuedOperationType.upload));
    });

    test(
        'QueuedSyncOperation should work without syncId for backward compatibility',
        () {
      final operation = QueuedSyncOperation(
                documentId: 'doc-123',
        type: QueuedOperationType.upload,
        queuedAt: DateTime.now(),
        operationData: {'test': 'data'},
      );

      expect(operation.syncId, isNull);
      expect(operation.documentId, equals('doc-123'));
      expect(operation.type, equals(QueuedOperationType.upload));
    });

    test('QueuedSyncOperation toJson/fromJson should preserve syncId', () {
      final operation = QueuedSyncOperation(
                documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        queuedAt: DateTime.now(),
        operationData: {'test': 'data'},
      );

      final json = operation.toJson();
      final restored = QueuedSyncOperation.fromJson(json);

      expect(restored.syncId, equals('sync-123'));
      expect(restored.documentId, equals('doc-123'));
      expect(restored.type, equals(QueuedOperationType.upload));
    });

    test('queueOperation should accept syncId parameter', () async {
      await queueService.queueOperation(
        documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        operationData: {'test': 'data'},
      );

      final status = queueService.getQueueStatus();
      expect(status.totalOperations, equals(1));

      final operations =
          queueService.getOperationsForDocument('doc-123', syncId: 'sync-123', userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");
      expect(operations.length, equals(1));
      expect(operations.first.syncId, equals('sync-123'));
    });

    test('getOperationsForDocument should work with syncId', () async {
      // Add operations with sync IDs
      await queueService.queueOperation(
        documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        operationData: {'test': 'data'},
      );

      await queueService.queueOperation(
        documentId: 'doc-456',
        syncId: 'sync-456',
        type: QueuedOperationType.update,
        operationData: {'test': 'data'},
      );

      // Test finding by sync ID
      final operationsForSync123 =
          queueService.getOperationsForDocument('doc-123', syncId: 'sync-123', userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");
      expect(operationsForSync123.length, equals(1));
      expect(operationsForSync123.first.syncId, equals('sync-123'));

      final operationsForSync456 =
          queueService.getOperationsForDocument('doc-456', syncId: 'sync-456', userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");
      expect(operationsForSync456.length, equals(1));
      expect(operationsForSync456.first.syncId, equals('sync-456'));
    });

    test('removeOperationsForDocument should work with syncId', () async {
      // Add operations with sync IDs
      await queueService.queueOperation(
        documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        operationData: {'test': 'data'},
      );

      await queueService.queueOperation(
        documentId: 'doc-456',
        syncId: 'sync-456',
        type: QueuedOperationType.update,
        operationData: {'test': 'data'},
      );

      expect(queueService.getQueueStatus().totalOperations, equals(2));

      // Remove by sync ID
      await queueService.removeOperationsForDocument('doc-123', syncId: 'sync-123', userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");

      expect(queueService.getQueueStatus().totalOperations, equals(1));

      final remaining =
          queueService.getOperationsForDocument('doc-456', syncId: 'sync-456', userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: amplify_core.TemporalDateTime.now(), lastModified: amplify_core.TemporalDateTime.now(), version: 1, syncState: "pending");
      expect(remaining.length, equals(1));
      expect(remaining.first.syncId, equals('sync-456'));
    });
  });
}
