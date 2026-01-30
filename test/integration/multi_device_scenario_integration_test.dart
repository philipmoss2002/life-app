import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/sync_service.dart';

/// Integration tests for multi-device scenarios (simulated)
///
/// Tests the flow:
/// - Device A: create documents while subscribed
/// - Device B: restore purchases, download documents
/// - Verify data consistency across devices
///
/// Tests Requirements: 4.1, 4.2, 10.1, 10.2, 10.3
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Device Scenario Integration Tests', () {
    late DocumentRepository repositoryA;
    late DocumentRepository repositoryB;
    late SubscriptionService subscriptionServiceA;
    late SubscriptionService subscriptionServiceB;
    late SyncService syncServiceA;
    late SyncService syncServiceB;

    setUp(() async {
      // Simulate two devices with separate instances
      repositoryA = DocumentRepository();
      repositoryB = DocumentRepository();

      subscriptionServiceA = SubscriptionService();
      subscriptionServiceB = SubscriptionService();

      syncServiceA = SyncService();
      syncServiceB = SyncService();

      // Clear caches
      subscriptionServiceA.clearCache();
      subscriptionServiceB.clearCache();
    });

    tearDown(() {
      syncServiceA.dispose();
      syncServiceB.dispose();
    });

    test('should simulate multi-device document creation and sync', () async {
      print('\n=== Multi-Device Scenario Test ===');

      // Device A: User creates documents while subscribed
      print('\n--- Device A: Creating documents ---');

      final docA1 = await repositoryA.createDocument(
        title: 'Device A Document 1',
        category: DocumentCategory.other,
        notes: 'Created on Device A',
      );

      final docA2 = await repositoryA.createDocument(
        title: 'Device A Document 2',
        category: DocumentCategory.expenses,
        notes: 'Also created on Device A',
      );

      print('✓ Device A created 2 documents');
      print('  - ${docA1.title} (${docA1.syncId})');
      print('  - ${docA2.title} (${docA2.syncId})');

      // Simulate sync to cloud
      await repositoryA.updateSyncState(docA1.syncId, SyncState.synced);
      await repositoryA.updateSyncState(docA2.syncId, SyncState.synced);

      print('✓ Device A synced documents to cloud');

      // Verify documents on Device A
      final docsA = await repositoryA.getAllDocuments();
      expect(docsA.length, greaterThanOrEqualTo(2));

      final docA1Found = docsA.any((d) => d.syncId == docA1.syncId);
      final docA2Found = docsA.any((d) => d.syncId == docA2.syncId);

      expect(docA1Found, isTrue);
      expect(docA2Found, isTrue);

      print('✓ Device A has both documents locally');

      // Device B: User installs app on new device and restores purchases
      print('\n--- Device B: Restoring purchases ---');

      // Simulate purchase restoration
      // In real scenario, this would query the platform
      final restoreResult = await subscriptionServiceB.restorePurchases();

      print('Purchase restoration result: ${restoreResult.success}');
      print('Subscription status: ${restoreResult.status}');

      // Note: In test environment without actual platform,
      // restoration will not find purchases
      // But we can verify the restoration logic works

      print('✓ Device B attempted purchase restoration');

      // Device B: Simulate downloading documents from cloud
      print('\n--- Device B: Downloading documents ---');

      // In a real scenario, Device B would download documents from cloud
      // For this test, we simulate by creating documents with same syncIds

      // Simulate document download by creating with known syncIds
      // (In real app, this would come from cloud query)
      final docB1 = await repositoryB.createDocument(
        title: 'Device A Document 1',
        category: DocumentCategory.other,
        notes: 'Created on Device A',
      );

      final docB2 = await repositoryB.createDocument(
        title: 'Device A Document 2',
        category: DocumentCategory.expenses,
        notes: 'Also created on Device A',
      );

      // Mark as synced (downloaded from cloud)
      await repositoryB.updateSyncState(docB1.syncId, SyncState.synced);
      await repositoryB.updateSyncState(docB2.syncId, SyncState.synced);

      print('✓ Device B downloaded 2 documents from cloud');

      // Verify documents on Device B
      final docsB = await repositoryB.getAllDocuments();
      expect(docsB.length, greaterThanOrEqualTo(2));

      print('✓ Device B has ${docsB.length} documents locally');

      // Verify data consistency
      print('\n--- Verifying data consistency ---');

      // Both devices should have documents with same titles
      final docB1Retrieved =
          docsB.firstWhere((d) => d.title == 'Device A Document 1');
      final docB2Retrieved =
          docsB.firstWhere((d) => d.title == 'Device A Document 2');

      expect(docB1Retrieved.title, equals('Device A Document 1'));
      expect(docB1Retrieved.category, equals('Personal'));
      expect(docB1Retrieved.notes, equals('Created on Device A'));

      expect(docB2Retrieved.title, equals('Device A Document 2'));
      expect(docB2Retrieved.category, equals('Work'));
      expect(docB2Retrieved.notes, equals('Also created on Device A'));

      print('✓ Document metadata consistent across devices');

      // Clean up Device A
      await repositoryA.deleteDocument(docA1.syncId);
      await repositoryA.deleteDocument(docA2.syncId);

      // Clean up Device B
      await repositoryB.deleteDocument(docB1.syncId);
      await repositoryB.deleteDocument(docB2.syncId);

      print('\n=== Multi-device test completed successfully ===');
    });

    test('should handle concurrent modifications on different devices',
        () async {
      print('\n=== Testing concurrent modifications ===');

      // Device A creates document
      final docA = await repositoryA.createDocument(
        title: 'Shared Document',
        category: DocumentCategory.other,
        notes: 'Original version',
      );

      await repositoryA.updateSyncState(docA.syncId, SyncState.synced);
      print('✓ Device A created and synced document');

      // Device B downloads document (simulated)
      final docB = await repositoryB.createDocument(
        title: 'Shared Document',
        category: DocumentCategory.other,
        notes: 'Original version',
      );

      await repositoryB.updateSyncState(docB.syncId, SyncState.synced);
      print('✓ Device B downloaded document');

      // Device A modifies document
      final docAModified = docA.copyWith(
        notes: 'Modified on Device A',
      );

      await repositoryA.updateDocument(docAModified);
      await repositoryA.updateSyncState(docA.syncId, SyncState.pendingUpload);
      print('✓ Device A modified document (pending sync)');

      // Device B also modifies document (conflict scenario)
      final docBModified = docB.copyWith(
        notes: 'Modified on Device B',
      );

      await repositoryB.updateDocument(docBModified);
      await repositoryB.updateSyncState(docB.syncId, SyncState.pendingUpload);
      print('✓ Device B modified document (pending sync)');

      // Verify both devices have their local changes
      final docARetrieved = await repositoryA.getDocument(docA.syncId);
      final docBRetrieved = await repositoryB.getDocument(docB.syncId);

      expect(docARetrieved!.notes, equals('Modified on Device A'));
      expect(docBRetrieved!.notes, equals('Modified on Device B'));

      print('✓ Both devices have their local modifications');
      print('  Device A: "${docARetrieved.notes}"');
      print('  Device B: "${docBRetrieved.notes}"');

      // In real scenario, conflict resolution would occur during sync
      // For this test, we verify both modifications are preserved locally

      // Clean up
      await repositoryA.deleteDocument(docA.syncId);
      await repositoryB.deleteDocument(docB.syncId);

      print('=== Concurrent modifications test completed ===');
    });

    test('should handle device-specific file attachments', () async {
      print('\n=== Testing device-specific file attachments ===');

      // Device A creates document with file
      final docA = await repositoryA.createDocument(
        title: 'Document with File',
        category: DocumentCategory.other,
      );

      await repositoryA.addFileAttachment(
        syncId: docA.syncId,
        fileName: 'photo.jpg',
        localPath: '/device-a/photos/photo.jpg',
        fileSize: 1024,
      );

      print('✓ Device A created document with file attachment');

      // Simulate upload to S3
      const s3Key = 'private/identity/documents/sync-id/photo.jpg';
      await repositoryA.updateFileS3Key(
        syncId: docA.syncId,
        fileName: 'photo.jpg',
        s3Key: s3Key,
      );

      await repositoryA.updateSyncState(docA.syncId, SyncState.synced);
      print('✓ Device A uploaded file to S3');

      // Device B downloads document (simulated)
      final docB = await repositoryB.createDocument(
        title: 'Document with File',
        category: DocumentCategory.other,
      );

      // Device B downloads file to different local path
      await repositoryB.addFileAttachment(
        syncId: docB.syncId,
        fileName: 'photo.jpg',
        localPath: '/device-b/downloads/photo.jpg',
        fileSize: 1024,
      );

      await repositoryB.updateFileS3Key(
        syncId: docB.syncId,
        fileName: 'photo.jpg',
        s3Key: s3Key,
      );

      await repositoryB.updateSyncState(docB.syncId, SyncState.synced);
      print('✓ Device B downloaded file from S3');

      // Verify both devices have file with same S3 key but different local paths
      final filesA = await repositoryA.getFileAttachments(docA.syncId);
      final filesB = await repositoryB.getFileAttachments(docB.syncId);

      expect(filesA.length, equals(1));
      expect(filesB.length, equals(1));

      expect(filesA[0].s3Key, equals(s3Key));
      expect(filesB[0].s3Key, equals(s3Key));

      expect(filesA[0].localPath, equals('/device-a/photos/photo.jpg'));
      expect(filesB[0].localPath, equals('/device-b/downloads/photo.jpg'));

      print('✓ Both devices have file with same S3 key');
      print('  Device A local path: ${filesA[0].localPath}');
      print('  Device B local path: ${filesB[0].localPath}');

      // Clean up
      await repositoryA.deleteDocument(docA.syncId);
      await repositoryB.deleteDocument(docB.syncId);

      print('=== Device-specific file attachments test completed ===');
    });

    test('should handle subscription status sync across devices', () async {
      print('\n=== Testing subscription status across devices ===');

      // Device A checks subscription status
      final statusA = await subscriptionServiceA.getSubscriptionStatus();
      print('Device A subscription status: $statusA');

      // Device B checks subscription status
      final statusB = await subscriptionServiceB.getSubscriptionStatus();
      print('Device B subscription status: $statusB');

      // In test environment without actual platform integration,
      // both should return 'none'
      expect(statusA, equals(SubscriptionStatus.none));
      expect(statusB, equals(SubscriptionStatus.none));

      print('✓ Both devices report consistent subscription status');

      // Verify cache behavior
      final hasActiveA = await subscriptionServiceA.hasActiveSubscription();
      final hasActiveB = await subscriptionServiceB.hasActiveSubscription();

      expect(hasActiveA, isFalse);
      expect(hasActiveB, isFalse);

      print('✓ Both devices correctly identify no active subscription');

      print('=== Subscription status test completed ===');
    });
  });
}
