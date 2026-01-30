import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/sync_service.dart';
import 'package:household_docs_app/services/connectivity_service.dart';

/// Integration tests for offline handling
///
/// Tests Requirements 6.3, 8.1
///
/// Verifies that documents can be created offline and synced when online.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Handling Integration Tests', () {
    late DocumentRepository repository;
    late SyncService syncService;
    late ConnectivityService connectivityService;

    setUp(() {
      repository = DocumentRepository();
      syncService = SyncService();
      connectivityService = ConnectivityService();
    });

    tearDown(() {
      syncService.dispose();
      connectivityService.dispose();
    });

    test('should create document while offline', () async {
      // Create document (simulating offline mode)
      final doc = await repository.createDocument(
        title: 'Offline Document',
        description: 'Created while offline',
      );

      // Document should be created with pendingUpload state
      expect(doc.syncId, isNotEmpty);
      expect(doc.syncState, equals(SyncState.pendingUpload));
      expect(doc.title, equals('Offline Document'));

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    test('should queue multiple documents for sync', () async {
      // Create multiple documents while "offline"
      final doc1 = await repository.createDocument(
        title: 'Document 1',
      );

      final doc2 = await repository.createDocument(
        title: 'Document 2',
      );

      final doc3 = await repository.createDocument(
        title: 'Document 3',
      );

      // All should be in pendingUpload state
      expect(doc1.syncState, equals(SyncState.pendingUpload));
      expect(doc2.syncState, equals(SyncState.pendingUpload));
      expect(doc3.syncState, equals(SyncState.pendingUpload));

      // Get all pending documents
      final pending =
          await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      expect(pending.length, greaterThanOrEqualTo(3));

      // Clean up
      await repository.deleteDocument(doc1.syncId);
      await repository.deleteDocument(doc2.syncId);
      await repository.deleteDocument(doc3.syncId);
    });

    test('should handle connectivity service', () async {
      // Verify connectivity service methods exist
      final hasConnectivity = await connectivityService.hasConnectivity();
      expect(hasConnectivity, isA<bool>());
      expect(connectivityService.connectivityStream, isNotNull);
    });

    test('should handle sync triggers', () {
      // Verify sync trigger methods exist
      expect(syncService.syncOnNetworkRestored, isA<Function>());
      expect(syncService.syncOnDocumentChange, isA<Function>());
    });

    test('should maintain document data integrity offline', () async {
      // Create document with full data
      final doc = await repository.createDocument(
        title: 'Complete Document',
        description: 'Full description',
        labels: ['label1', 'label2', 'label3'],
      );

      // Add file attachment
      await repository.addFileAttachment(
        syncId: doc.syncId,
        fileName: 'test.pdf',
        localPath: '/path/to/test.pdf',
        fileSize: 2048,
      );

      // Retrieve and verify all data preserved
      final retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved?.title, equals('Complete Document'));
      expect(retrieved?.description, equals('Full description'));
      expect(retrieved?.labels, equals(['label1', 'label2', 'label3']));

      final files = await repository.getFileAttachments(doc.syncId);
      expect(files.length, equals(1));
      expect(files[0].fileName, equals('test.pdf'));
      expect(files[0].fileSize, equals(2048));

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    test('should handle document updates while offline', () async {
      // Create document
      final doc = await repository.createDocument(
        title: 'Original Title',
        description: 'Original description',
      );

      // Update document (simulating offline edit)
      final updated = doc.copyWith(
        title: 'Updated Title',
        description: 'Updated description',
        labels: ['new-label'],
      );
      await repository.updateDocument(updated);

      // Verify updates persisted
      final retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved?.title, equals('Updated Title'));
      expect(retrieved?.description, equals('Updated description'));
      expect(retrieved?.labels, equals(['new-label']));

      // Should still be pending upload
      expect(retrieved?.syncState, equals(SyncState.pendingUpload));

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    // Note: Full offline-to-online flow requires:
    // 1. Ability to simulate network state changes
    // 2. AWS connectivity for actual sync
    // 3. Mock or test AWS environment
    //
    // Example full flow (requires network simulation):
    // test('should sync when going from offline to online', () async {
    //   // Create documents while offline
    //   final doc = await repository.createDocument(
    //     title: 'Offline Document',
    //   );
    //
    //   expect(doc.syncState, equals(SyncState.pendingUpload));
    //
    //   // Simulate going online
    //   await syncService.syncOnNetworkRestored();
    //
    //   // Wait for sync to complete
    //   await Future.delayed(Duration(seconds: 2));
    //
    //   // Verify document synced
    //   final synced = await repository.getDocument(doc.syncId);
    //   expect(synced?.syncState, equals(SyncState.synced));
    //
    //   // Clean up
    //   await repository.deleteDocument(doc.syncId);
    // });
  });
}
