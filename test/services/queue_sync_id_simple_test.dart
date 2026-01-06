import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/offline_sync_queue_service.dart';

void main() {
  group('Queue Sync ID Simple Tests', () {
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

    test('QueuedSyncOperation toJson should include syncId in JSON', () {
      final operation = QueuedSyncOperation(
                documentId: 'doc-123',
        syncId: 'sync-123',
        type: QueuedOperationType.upload,
        queuedAt: DateTime.now(),
        operationData: {'test': 'data'},
      );

      final json = operation.toJson();

      expect(json['syncId'], equals('sync-123'));
      expect(json['documentId'], equals('doc-123'));
      expect(json['type'], equals('upload'));
    });

    test('QueuedSyncOperation fromJson should handle null syncId', () {
      final json = {
        'id': 'test-operation',
        'documentId': 'doc-123',
        'syncId': null,
        'type': 'upload',
        'queuedAt': DateTime.now().toIso8601String(),
        'retryCount': 0,
        'operationData': {'test': 'data'},
        'priority': 0,
      };

      final operation = QueuedSyncOperation.fromJson(json);

      expect(operation.syncId, isNull);
      expect(operation.documentId, equals('doc-123'));
      expect(operation.type, equals(QueuedOperationType.upload));
    });
  });
}
