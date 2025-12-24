import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/cloud_sync_service.dart';
import '../../lib/models/Document.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

void main() {
  group('Sync Coordinator Updates', () {
    test('SyncOperation should include syncId field', () {
      final document = Document(syncId: SyncIdentifierService.generate(, userId: "test-user", title: "Test Document", category: "Test", filePaths: ["test.pdf"], createdAt: TemporalDateTime.now(), lastModified: TemporalDateTime.now(), version: 1, syncState: "pending"),

        userId: 'test-user',
        title: 'Test Document',
        category: 'test',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 1,
        syncState: 'notSynced',
        syncId: 'test-sync-id-123',
      );

      final operation = SyncOperation(
                documentId: document.syncId,
        syncId: document.syncId,
        type: SyncOperationType.upload,
        document: document,
      );

      expect(operation.syncId, equals('test-sync-id-123'));
      expect(operation.documentId, equals(document.syncId));
      expect(operation.type, equals(SyncOperationType.upload));
    });

    test('SyncOperation copyWith should preserve syncId', () {
      final operation = SyncOperation(
                documentId: 'doc-123',
        syncId: 'sync-123',
        type: SyncOperationType.upload,
      );

      final copied = operation.copyWith(retryCount: 1);

      expect(copied.syncId, equals('sync-123'));
      expect(copied.documentId, equals('doc-123'));
      expect(copied.retryCount, equals(1));
      expect(copied.type, equals(SyncOperationType.upload));
    });

    test('SyncOperation should work without syncId for backward compatibility',
        () {
      final operation = SyncOperation(
                documentId: 'doc-123',
        type: SyncOperationType.upload,
      );

      expect(operation.syncId, isNull);
      expect(operation.documentId, equals('doc-123'));
      expect(operation.type, equals(SyncOperationType.upload));
    });
  });
}
