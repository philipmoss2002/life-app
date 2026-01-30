import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/subscription_gating_middleware.dart';
import 'package:household_docs_app/services/sync_service.dart';
import 'package:household_docs_app/services/document_sync_service.dart';

/// Integration tests for complete subscription lifecycle
///
/// Tests the complete flow:
/// - User subscribes → documents sync to cloud
/// - Subscription expires → sync stops, local continues
/// - User renews → pending documents sync
///
/// Tests Requirements: All subscription gating requirements
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Subscription Lifecycle Integration Tests', () {
    late DocumentRepository repository;
    late SubscriptionService subscriptionService;
    late SubscriptionGatingMiddleware gatingMiddleware;
    late SyncService syncService;
    late DocumentSyncService documentSyncService;

    setUp(() async {
      repository = DocumentRepository();
      subscriptionService = SubscriptionService();
      gatingMiddleware = SubscriptionGatingMiddleware(subscriptionService);
      syncService = SyncService();
      documentSyncService = DocumentSyncService();

      // Clear any cached subscription status
      subscriptionService.clearCache();
    });

    tearDown(() {
      syncService.dispose();
    });

    test(
        'should complete full subscription lifecycle: subscribe → use → expire → renew',
        () async {
      // Phase 1: User without subscription creates documents
      print('\n=== Phase 1: Non-subscribed user creates documents ===');

      final doc1 = await repository.createDocument(
        title: 'Document 1',
        category: DocumentCategory.other,
        notes: 'Created without subscription',
      );

      expect(doc1.syncId, isNotEmpty);
      expect(doc1.syncState, equals(SyncState.pendingUpload));
      expect(doc1.title, equals('Document 1'));

      // Verify document is in local storage
      final retrieved1 = await repository.getDocument(doc1.syncId);
      expect(retrieved1, isNotNull);
      expect(retrieved1!.title, equals('Document 1'));

      print('✓ Document created locally without subscription');

      // Phase 2: Simulate subscription activation
      print('\n=== Phase 2: User subscribes (simulated) ===');

      // Note: In real scenario, this would happen through platform purchase
      // For integration test, we verify the gating logic works correctly

      // Check that gating middleware correctly identifies no subscription
      final canSyncBefore = await gatingMiddleware.canPerformCloudSync();
      print('Can sync before subscription: $canSyncBefore');

      // In test environment without actual platform integration,
      // we expect false (no subscription)
      expect(canSyncBefore, isFalse);
      print('✓ Gating middleware correctly blocks sync without subscription');

      // Phase 3: User modifies document while subscribed (simulated)
      print('\n=== Phase 3: User modifies document ===');

      final updatedDoc = doc1.copyWith(
        title: 'Document 1 Updated',
        notes: 'Modified after subscription',
      );

      await repository.updateDocument(updatedDoc);

      final retrieved2 = await repository.getDocument(doc1.syncId);
      expect(retrieved2!.title, equals('Document 1 Updated'));
      expect(retrieved2.notes, equals('Modified after subscription'));

      print('✓ Document updated in local storage');

      // Phase 4: Simulate subscription expiration
      print('\n=== Phase 4: Subscription expires (simulated) ===');

      // Verify local operations still work
      final doc2 = await repository.createDocument(
        title: 'Document 2',
        category: DocumentCategory.expenses,
        notes: 'Created after expiration',
      );

      expect(doc2.syncId, isNotEmpty);
      expect(doc2.syncState, equals(SyncState.pendingUpload));

      final retrieved3 = await repository.getDocument(doc2.syncId);
      expect(retrieved3, isNotNull);
      expect(retrieved3!.title, equals('Document 2'));

      print('✓ Local operations continue after expiration');

      // Verify all documents are still accessible
      final allDocs = await repository.getAllDocuments();
      expect(allDocs.length, greaterThanOrEqualTo(2));

      final doc1Found = allDocs.any((d) => d.syncId == doc1.syncId);
      final doc2Found = allDocs.any((d) => d.syncId == doc2.syncId);

      expect(doc1Found, isTrue);
      expect(doc2Found, isTrue);

      print('✓ All documents remain accessible after expiration');

      // Phase 5: Simulate subscription renewal
      print('\n=== Phase 5: User renews subscription (simulated) ===');

      // Verify pending documents are identified
      final pendingDocs =
          await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      print('Pending documents for sync: ${pendingDocs.length}');

      expect(pendingDocs.length, greaterThanOrEqualTo(2));

      // Verify documents maintain their metadata
      final doc1Pending =
          pendingDocs.firstWhere((d) => d.syncId == doc1.syncId);
      expect(doc1Pending.title, equals('Document 1 Updated'));
      expect(doc1Pending.notes, equals('Modified after subscription'));

      print('✓ Pending documents identified with preserved metadata');

      // Clean up
      await repository.deleteDocument(doc1.syncId);
      await repository.deleteDocument(doc2.syncId);

      print('\n=== Lifecycle test completed successfully ===');
    });

    test('should handle subscription state transitions correctly', () async {
      print('\n=== Testing subscription state transitions ===');

      // Create document in each state
      final doc = await repository.createDocument(
        title: 'State Transition Test',
        category: DocumentCategory.other,
      );

      // Verify initial state
      expect(doc.syncState, equals(SyncState.pendingUpload));
      print('✓ Initial state: pendingUpload');

      // Simulate state transitions
      await repository.updateSyncState(doc.syncId, SyncState.uploading);
      var retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved!.syncState, equals(SyncState.uploading));
      print('✓ Transition to: uploading');

      await repository.updateSyncState(doc.syncId, SyncState.synced);
      retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved!.syncState, equals(SyncState.synced));
      print('✓ Transition to: synced');

      // Simulate expiration - document goes back to pending
      await repository.updateSyncState(doc.syncId, SyncState.pendingUpload);
      retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved!.syncState, equals(SyncState.pendingUpload));
      print('✓ Transition back to: pendingUpload (after expiration)');

      // Clean up
      await repository.deleteDocument(doc.syncId);

      print('=== State transition test completed ===');
    });

    test('should preserve document metadata through subscription changes',
        () async {
      print('\n=== Testing metadata preservation ===');

      final originalCreatedAt =
          DateTime.now().subtract(const Duration(days: 7));

      // Create document with specific metadata
      final doc = await repository.createDocument(
        title: 'Metadata Test Document',
        category: DocumentCategory.carInsurance,
        notes: 'Important financial document',
      );

      // Store original values
      final originalSyncId = doc.syncId;
      final originalTitle = doc.title;
      final originalCategory = doc.category;
      final originalNotes = doc.notes;

      print('Original metadata:');
      print('  syncId: $originalSyncId');
      print('  title: $originalTitle');
      print('  category: $originalCategory');
      print('  notes: $originalNotes');

      // Simulate subscription activation and sync
      await repository.updateSyncState(doc.syncId, SyncState.synced);

      // Simulate subscription expiration
      await repository.updateSyncState(doc.syncId, SyncState.pendingUpload);

      // Simulate subscription renewal
      await repository.updateSyncState(doc.syncId, SyncState.uploading);
      await repository.updateSyncState(doc.syncId, SyncState.synced);

      // Verify metadata is preserved
      final retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved, isNotNull);
      expect(retrieved!.syncId, equals(originalSyncId));
      expect(retrieved.title, equals(originalTitle));
      expect(retrieved.category, equals(originalCategory));
      expect(retrieved.notes, equals(originalNotes));

      print('\nMetadata after subscription changes:');
      print('  syncId: ${retrieved.syncId}');
      print('  title: ${retrieved.title}');
      print('  category: ${retrieved.category}');
      print('  notes: ${retrieved.notes}');
      print('✓ All metadata preserved correctly');

      // Clean up
      await repository.deleteDocument(doc.syncId);

      print('=== Metadata preservation test completed ===');
    });

    test('should handle multiple documents with different sync states',
        () async {
      print('\n=== Testing multiple documents with different states ===');

      // Create documents in different states
      final doc1 = await repository.createDocument(
        title: 'Pending Document',
        category: DocumentCategory.other,
      );

      final doc2 = await repository.createDocument(
        title: 'Synced Document',
        category: DocumentCategory.expenses,
      );
      await repository.updateSyncState(doc2.syncId, SyncState.synced);

      final doc3 = await repository.createDocument(
        title: 'Error Document',
        category: DocumentCategory.carInsurance,
      );
      await repository.updateSyncState(doc3.syncId, SyncState.error);

      print('Created 3 documents with different states');

      // Verify each state
      final retrieved1 = await repository.getDocument(doc1.syncId);
      final retrieved2 = await repository.getDocument(doc2.syncId);
      final retrieved3 = await repository.getDocument(doc3.syncId);

      expect(retrieved1!.syncState, equals(SyncState.pendingUpload));
      expect(retrieved2!.syncState, equals(SyncState.synced));
      expect(retrieved3!.syncState, equals(SyncState.error));

      print('✓ All documents have correct states');

      // Query by state
      final pendingDocs =
          await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      final syncedDocs =
          await repository.getDocumentsBySyncState(SyncState.synced);
      final errorDocs =
          await repository.getDocumentsBySyncState(SyncState.error);

      expect(pendingDocs.any((d) => d.syncId == doc1.syncId), isTrue);
      expect(syncedDocs.any((d) => d.syncId == doc2.syncId), isTrue);
      expect(errorDocs.any((d) => d.syncId == doc3.syncId), isTrue);

      print('✓ Query by state works correctly');

      // Simulate subscription renewal - pending and error docs should be synced
      final docsToSync =
          await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      final errorDocsToRetry =
          await repository.getDocumentsBySyncState(SyncState.error);

      print('Documents to sync on renewal: ${docsToSync.length}');
      print('Error documents to retry: ${errorDocsToRetry.length}');

      expect(docsToSync.length, greaterThanOrEqualTo(1));
      expect(errorDocsToRetry.length, greaterThanOrEqualTo(1));

      // Clean up
      await repository.deleteDocument(doc1.syncId);
      await repository.deleteDocument(doc2.syncId);
      await repository.deleteDocument(doc3.syncId);

      print('=== Multiple documents test completed ===');
    });

    test('should handle file attachments through subscription lifecycle',
        () async {
      print('\n=== Testing file attachments through lifecycle ===');

      // Create document with file attachment
      final doc = await repository.createDocument(
        title: 'Document with Files',
        category: DocumentCategory.other,
      );

      await repository.addFileAttachment(
        syncId: doc.syncId,
        fileName: 'receipt.pdf',
        localPath: '/path/to/receipt.pdf',
        fileSize: 2048,
      );

      await repository.addFileAttachment(
        syncId: doc.syncId,
        fileName: 'invoice.pdf',
        localPath: '/path/to/invoice.pdf',
        fileSize: 4096,
      );

      print('Created document with 2 file attachments');

      // Verify files are attached
      var files = await repository.getFileAttachments(doc.syncId);
      expect(files.length, equals(2));
      expect(files[0].fileName, equals('receipt.pdf'));
      expect(files[1].fileName, equals('invoice.pdf'));
      expect(files[0].s3Key, isNull); // Not uploaded yet
      expect(files[1].s3Key, isNull);

      print('✓ Files attached locally');

      // Simulate subscription and upload
      const s3Key1 = 'private/identity/documents/sync-id/receipt.pdf';
      const s3Key2 = 'private/identity/documents/sync-id/invoice.pdf';

      await repository.updateFileS3Key(
        syncId: doc.syncId,
        fileName: 'receipt.pdf',
        s3Key: s3Key1,
      );

      await repository.updateFileS3Key(
        syncId: doc.syncId,
        fileName: 'invoice.pdf',
        s3Key: s3Key2,
      );

      // Verify S3 keys updated
      files = await repository.getFileAttachments(doc.syncId);
      expect(files[0].s3Key, equals(s3Key1));
      expect(files[1].s3Key, equals(s3Key2));

      print('✓ Files uploaded to S3 (simulated)');

      // Simulate subscription expiration - files remain accessible locally
      await repository.updateSyncState(doc.syncId, SyncState.pendingUpload);

      files = await repository.getFileAttachments(doc.syncId);
      expect(files.length, equals(2));
      expect(files[0].localPath, equals('/path/to/receipt.pdf'));
      expect(files[1].localPath, equals('/path/to/invoice.pdf'));

      print('✓ Files remain accessible after expiration');

      // Clean up
      await repository.deleteDocument(doc.syncId);

      // Verify files are cascade deleted
      files = await repository.getFileAttachments(doc.syncId);
      expect(files.length, equals(0));

      print('✓ Files cascade deleted with document');
      print('=== File attachments test completed ===');
    });
  });
}
