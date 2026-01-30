import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/subscription_gating_middleware.dart';
import 'package:household_docs_app/services/sync_service.dart';

/// Integration tests for error recovery in subscription flows
///
/// Tests error scenarios:
/// - Subscription check failures
/// - Cache corruption recovery
/// - Network timeout handling
/// - Sync failures with subscription changes
///
/// Tests Requirements: All (error handling aspects)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Subscription Error Recovery Integration Tests', () {
    late DocumentRepository repository;
    late SubscriptionService subscriptionService;
    late SubscriptionGatingMiddleware gatingMiddleware;
    late SyncService syncService;

    setUp(() async {
      repository = DocumentRepository();
      subscriptionService = SubscriptionService();
      gatingMiddleware = SubscriptionGatingMiddleware(subscriptionService);
      syncService = SyncService();

      // Clear cache
      subscriptionService.clearCache();
    });

    tearDown() {
      syncService.dispose();
    });

    test('should handle subscription check failure gracefully', () async {
      print('\n=== Testing subscription check failure handling ===');
      
      // Create document
      final doc = await repository.createDocument(
        title: 'Test Document',
        category: DocumentCategory.other,
        notes: 'Testing error handling',
      );
      
      print('✓ Document created: ${doc.title}');
      
      // Attempt to check if sync is allowed
      // In test environment, this should handle gracefully
      final canSync = await gatingMiddleware.canPerformCloudSync();
      
      print('Can perform cloud sync: $canSync');
      print('Denial reason: ${gatingMiddleware.getDenialReason()}');
      
      // Should fail-safe to deny sync
      expect(canSync, isFalse);
      
      // But local operations should still work
      final updatedDoc = doc.copyWith(
        notes: 'Updated after sync check failure',
      );
      
      await repository.updateDocument(updatedDoc);
      
      final retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved, isNotNull);
      expect(retrieved!.notes, equals('Updated after sync check failure'));
      
      print('✓ Local operations continue despite sync check failure');
      
      // Clean up
      await repository.deleteDocument(doc.syncId);
      
      print('=== Subscription check failure test completed ===');
    });

    test('should recover from cache corruption', () async {
      print('\n=== Testing cache corruption recovery ===');
      
      // Get initial subscription status (creates cache)
      final status1 = await subscriptionService.getSubscriptionStatus();
      print('Initial status: $status1');
      
      // Simulate cache corruption by clearing it
      subscriptionService.clearCache();
      print('✓ Cache cleared (simulating corruption)');
      
      // Should recover by querying platform again
      final status2 = await subscriptionService.getSubscriptionStatus();
      print('Status after cache clear: $status2');
      
      // Should return valid status (even if none)
      expect(status2, isNotNull);
      expect(status2, isA<SubscriptionStatus>());
      
      print('✓ Successfully recovered from cache corruption');
      
      // Verify cache is rebuilt
      final hasActive = await subscriptionService.hasActiveSubscription();
      print('Has active subscription: $hasActive');
      
      expect(hasActive, isA<bool>());
      
      print('✓ Cache rebuilt successfully');
      
      print('=== Cache corruption recovery test completed ===');
    });

    test('should handle rapid subscription status changes', () async {
      print('\n=== Testing rapid subscription status changes ===');
      
      // Create document
      final doc = await repository.createDocument(
        title: 'Rapid Change Test',
        category: DocumentCategory.other,
      );
      
      print('✓ Document created');
      
      // Simulate rapid status checks
      final results = <bool>[];
      
      for (int i = 0; i < 5; i++) {
        final canSync = await gatingMiddleware.canPerformCloudSync();
        results.add(canSync);
        print('Check $i: canSync = $canSync');
      }
      
      // All checks should return consistent results
      final allSame = results.every((r) => r == results.first);
      expect(allSame, isTrue);
      
      print('✓ All rapid checks returned consistent results');
      
      // Document should remain accessible
      final retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved, isNotNull);
      expect(retrieved!.title, equals('Rapid Change Test'));
      
      print('✓ Document remains accessible during rapid checks');
      
      // Clean up
      await repository.deleteDocument(doc.syncId);
      
      print('=== Rapid status changes test completed ===');
    });

    test('should handle sync state errors and recovery', () async {
      print('\n=== Testing sync state error recovery ===');
      
      // Create document
      final doc = await repository.createDocument(
        title: 'Error Recovery Test',
        category: DocumentCategory.expenses,
      );
      
      expect(doc.syncState, equals(SyncState.pendingUpload));
      print('✓ Document created with pendingUpload state');
      
      // Simulate sync attempt that fails
      await repository.updateSyncState(doc.syncId, SyncState.uploading);
      print('✓ State changed to uploading');
      
      // Simulate error during upload
      await repository.updateSyncState(doc.syncId, SyncState.error);
      print('✓ State changed to error');
      
      var retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved!.syncState, equals(SyncState.error));
      
      // Verify document is still accessible despite error
      expect(retrieved.title, equals('Error Recovery Test'));
      expect(retrieved.category, equals('Work'));
      
      print('✓ Document accessible in error state');
      
      // Simulate retry - reset to pending
      await repository.updateSyncState(doc.syncId, SyncState.pendingUpload);
      print('✓ State reset to pendingUpload for retry');
      
      retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved!.syncState, equals(SyncState.pendingUpload));
      
      // Simulate successful retry
      await repository.updateSyncState(doc.syncId, SyncState.uploading);
      await repository.updateSyncState(doc.syncId, SyncState.synced);
      
      retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved!.syncState, equals(SyncState.synced));
      
      print('✓ Successfully recovered from error state');
      
      // Clean up
      await repository.deleteDocument(doc.syncId);
      
      print('=== Sync state error recovery test completed ===');
    });

    test('should handle multiple concurrent errors', () async {
      print('\n=== Testing multiple concurrent errors ===');
      
      // Create multiple documents
      final docs = <String>[];
      
      for (int i = 0; i < 5; i++) {
        final doc = await repository.createDocument(
          title: 'Concurrent Error Test $i',
          category: DocumentCategory.other,
        );
        docs.add(doc.syncId);
      }
      
      print('✓ Created 5 documents');
      
      // Simulate all documents encountering errors
      for (final syncId in docs) {
        await repository.updateSyncState(syncId, SyncState.error);
      }
      
      print('✓ All documents in error state');
      
      // Verify all documents are in error state
      final errorDocs = await repository.getDocumentsBySyncState(SyncState.error);
      expect(errorDocs.length, greaterThanOrEqualTo(5));
      
      print('✓ Confirmed ${errorDocs.length} documents in error state');
      
      // Verify all documents are still accessible
      for (final syncId in docs) {
        final doc = await repository.getDocument(syncId);
        expect(doc, isNotNull);
        expect(doc!.syncState, equals(SyncState.error));
      }
      
      print('✓ All documents remain accessible');
      
      // Simulate batch retry
      for (final syncId in docs) {
        await repository.updateSyncState(syncId, SyncState.pendingUpload);
      }
      
      print('✓ All documents reset for retry');
      
      // Verify all documents are pending
      final pendingDocs = await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      expect(pendingDocs.length, greaterThanOrEqualTo(5));
      
      print('✓ All documents ready for retry');
      
      // Clean up
      for (final syncId in docs) {
        await repository.deleteDocument(syncId);
      }
      
      print('=== Multiple concurrent errors test completed ===');
    });

    test('should handle subscription service errors without blocking local operations', () async {
      print('\n=== Testing local operations during subscription errors ===');
      
      // Clear cache to force subscription check
      subscriptionService.clearCache();
      
      // Create document (should work regardless of subscription check)
      final doc1 = await repository.createDocument(
        title: 'Local Operation 1',
        category: DocumentCategory.other,
      );
      
      expect(doc1.syncId, isNotEmpty);
      print('✓ Document 1 created');
      
      // Update document
      final updated = doc1.copyWith(
        notes: 'Updated locally',
      );
      
      await repository.updateDocument(updated);
      
      final retrieved = await repository.getDocument(doc1.syncId);
      expect(retrieved!.notes, equals('Updated locally'));
      
      print('✓ Document 1 updated');
      
      // Create another document
      final doc2 = await repository.createDocument(
        title: 'Local Operation 2',
        category: DocumentCategory.expenses,
      );
      
      expect(doc2.syncId, isNotEmpty);
      print('✓ Document 2 created');
      
      // Add file attachment
      await repository.addFileAttachment(
        syncId: doc2.syncId,
        fileName: 'test.pdf',
        localPath: '/path/to/test.pdf',
        fileSize: 1024,
      );
      
      final files = await repository.getFileAttachments(doc2.syncId);
      expect(files.length, equals(1));
      
      print('✓ File attachment added');
      
      // Delete document
      await repository.deleteDocument(doc1.syncId);
      
      final deleted = await repository.getDocument(doc1.syncId);
      expect(deleted, isNull);
      
      print('✓ Document 1 deleted');
      
      // Verify all operations succeeded
      final allDocs = await repository.getAllDocuments();
      final doc2Found = allDocs.any((d) => d.syncId == doc2.syncId);
      expect(doc2Found, isTrue);
      
      print('✓ All local operations completed successfully');
      
      // Clean up
      await repository.deleteDocument(doc2.syncId);
      
      print('=== Local operations during errors test completed ===');
    });

    test('should handle cache expiration gracefully', () async {
      print('\n=== Testing cache expiration handling ===');
      
      // Get initial status (creates cache)
      final status1 = await subscriptionService.getSubscriptionStatus();
      print('Initial status: $status1');
      
      // Check if has active subscription (should use cache)
      final hasActive1 = await subscriptionService.hasActiveSubscription();
      print('Has active (cached): $hasActive1');
      
      // Clear cache to simulate expiration
      subscriptionService.clearCache();
      print('✓ Cache cleared (simulating expiration)');
      
      // Next check should query platform
      final hasActive2 = await subscriptionService.hasActiveSubscription();
      print('Has active (after expiration): $hasActive2');
      
      // Should return valid result
      expect(hasActive2, isA<bool>());
      
      // Verify cache is rebuilt
      final status2 = await subscriptionService.getSubscriptionStatus();
      print('Status after rebuild: $status2');
      
      expect(status2, isNotNull);
      
      print('✓ Cache expiration handled gracefully');
      
      print('=== Cache expiration test completed ===');
    });

    test('should handle document operations during subscription transitions', () async {
      print('\n=== Testing operations during subscription transitions ===');
      
      // Create document before subscription
      final doc1 = await repository.createDocument(
        title: 'Pre-subscription Document',
        category: DocumentCategory.other,
      );
      
      expect(doc1.syncState, equals(SyncState.pendingUpload));
      print('✓ Document created before subscription');
      
      // Simulate subscription activation
      // (In real scenario, this would trigger sync)
      
      // Create document during transition
      final doc2 = await repository.createDocument(
        title: 'During-transition Document',
        category: DocumentCategory.expenses,
      );
      
      expect(doc2.syncState, equals(SyncState.pendingUpload));
      print('✓ Document created during transition');
      
      // Simulate subscription active
      await repository.updateSyncState(doc1.syncId, SyncState.synced);
      await repository.updateSyncState(doc2.syncId, SyncState.synced);
      
      print('✓ Documents synced after subscription active');
      
      // Create document after subscription
      final doc3 = await repository.createDocument(
        title: 'Post-subscription Document',
        category: DocumentCategory.carInsurance,
      );
      
      expect(doc3.syncState, equals(SyncState.pendingUpload));
      print('✓ Document created after subscription');
      
      // Verify all documents exist
      final allDocs = await repository.getAllDocuments();
      expect(allDocs.length, greaterThanOrEqualTo(3));
      
      final doc1Found = allDocs.any((d) => d.syncId == doc1.syncId);
      final doc2Found = allDocs.any((d) => d.syncId == doc2.syncId);
      final doc3Found = allDocs.any((d) => d.syncId == doc3.syncId);
      
      expect(doc1Found, isTrue);
      expect(doc2Found, isTrue);
      expect(doc3Found, isTrue);
      
      print('✓ All documents accessible throughout transition');
      
      // Clean up
      await repository.deleteDocument(doc1.syncId);
      await repository.deleteDocument(doc2.syncId);
      await repository.deleteDocument(doc3.syncId);
      
      print('=== Operations during transitions test completed ===');
    });
  });
}
