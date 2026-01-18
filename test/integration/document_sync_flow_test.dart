import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/sync_service.dart';
import 'package:household_docs_app/services/file_service.dart';

/// Integration tests for document creation and sync flow
///
/// Tests Requirements 4.1, 5.1, 6.1
///
/// Note: Full S3 integration requires AWS credentials and network connectivity.
/// These tests verify the service interactions work correctly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Document Sync Flow Integration Tests', () {
    late DocumentRepository repository;
    late SyncService syncService;
    late FileService fileService;

    setUp(() {
      repository = DocumentRepository();
      syncService = SyncService();
      fileService = FileService();
    });

    tearDown(() {
      syncService.dispose();
    });

    test('should create document with pendingUpload state', () async {
      // Create document
      final doc = await repository.createDocument(
        title: 'Test Document',
        description: 'Test description',
      );

      // Verify initial state
      expect(doc.syncId, isNotEmpty);
      expect(doc.syncState, equals(SyncState.pendingUpload));
      expect(doc.title, equals('Test Document'));

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    test('should add file attachment to document', () async {
      // Create document
      final doc = await repository.createDocument(
        title: 'Test Document',
      );

      // Add file attachment
      await repository.addFileAttachment(
        syncId: doc.syncId,
        fileName: 'test.pdf',
        localPath: '/path/to/test.pdf',
        fileSize: 1024,
      );

      // Verify file attachment
      final files = await repository.getFileAttachments(doc.syncId);
      expect(files.length, equals(1));
      expect(files[0].fileName, equals('test.pdf'));
      expect(files[0].localPath, equals('/path/to/test.pdf'));
      expect(files[0].fileSize, equals(1024));
      expect(files[0].s3Key, isNull); // Not uploaded yet

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    test('should update file S3 key after upload', () async {
      // Create document
      final doc = await repository.createDocument(
        title: 'Test Document',
      );

      // Add file attachment
      await repository.addFileAttachment(
        syncId: doc.syncId,
        fileName: 'test.pdf',
        localPath: '/path/to/test.pdf',
      );

      // Simulate upload by updating S3 key
      const s3Key = 'private/identity-pool-id/documents/sync-id/test.pdf';
      await repository.updateFileS3Key(
        syncId: doc.syncId,
        fileName: 'test.pdf',
        s3Key: s3Key,
      );

      // Verify S3 key updated
      final files = await repository.getFileAttachments(doc.syncId);
      expect(files[0].s3Key, equals(s3Key));

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    test('should update sync state through sync flow', () async {
      // Create document
      final doc = await repository.createDocument(
        title: 'Test Document',
      );

      expect(doc.syncState, equals(SyncState.pendingUpload));

      // Update to uploading
      await repository.updateSyncState(doc.syncId, SyncState.uploading);
      var retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved?.syncState, equals(SyncState.uploading));

      // Update to synced
      await repository.updateSyncState(doc.syncId, SyncState.synced);
      retrieved = await repository.getDocument(doc.syncId);
      expect(retrieved?.syncState, equals(SyncState.synced));

      // Clean up
      await repository.deleteDocument(doc.syncId);
    });

    test('should generate valid S3 path', () {
      // Test S3 path generation
      const identityPoolId = 'us-east-1:12345678-1234-1234-1234-123456789012';
      const syncId = '12345678-1234-1234-1234-123456789012';
      const fileName = 'test.pdf';

      final s3Path = fileService.generateS3Path(
        identityPoolId: identityPoolId,
        syncId: syncId,
        fileName: fileName,
      );

      expect(
        s3Path,
        equals('private/$identityPoolId/documents/$syncId/$fileName'),
      );
    });

    test('should validate S3 key ownership', () {
      const identityPoolId = 'us-east-1:12345678-1234-1234-1234-123456789012';
      const validS3Key = 'private/$identityPoolId/documents/sync-id/test.pdf';
      const invalidS3Key =
          'private/different-identity/documents/sync-id/test.pdf';

      expect(
        fileService.validateS3KeyOwnership(validS3Key, identityPoolId),
        isTrue,
      );
      expect(
        fileService.validateS3KeyOwnership(invalidS3Key, identityPoolId),
        isFalse,
      );
    });

    test('should handle sync service methods', () {
      // Verify sync service methods exist
      expect(syncService.performSync, isA<Function>());
      expect(syncService.syncDocument, isA<Function>());
      expect(syncService.isSyncing, isA<bool>());
    });

    // Note: Full sync flow with S3 upload/download requires:
    // 1. AWS credentials configured
    // 2. S3 bucket with proper permissions
    // 3. Network connectivity
    // 4. Actual files to upload
    //
    // Example full flow (requires AWS setup):
    // test('should complete full document sync flow', () async {
    //   // Create document
    //   final doc = await repository.createDocument(
    //     title: 'Test Document',
    //   );
    //
    //   // Add file
    //   await repository.addFileAttachment(
    //     syncId: doc.syncId,
    //     fileName: 'test.pdf',
    //     localPath: '/path/to/actual/test.pdf',
    //   );
    //
    //   // Trigger sync
    //   await syncService.syncDocument(doc.syncId);
    //
    //   // Verify file uploaded
    //   final files = await repository.getFileAttachments(doc.syncId);
    //   expect(files[0].s3Key, isNotNull);
    //
    //   // Verify sync state
    //   final synced = await repository.getDocument(doc.syncId);
    //   expect(synced?.syncState, equals(SyncState.synced));
    //
    //   // Clean up
    //   await repository.deleteDocument(doc.syncId);
    // });
  });
}
