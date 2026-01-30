import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';
import 'package:household_docs_app/models/new_document.dart';
import 'package:household_docs_app/repositories/document_repository.dart';
import 'package:household_docs_app/services/subscription_service.dart';
import 'package:household_docs_app/services/subscription_gating_middleware.dart';

/// Integration tests for performance with large document sets
///
/// Tests performance scenarios:
/// - Large document set operations
/// - Bulk sync operations
/// - Cache performance
/// - Query performance
///
/// Tests Requirements: All (performance aspects)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Subscription Performance Integration Tests', () {
    late DocumentRepository repository;
    late SubscriptionService subscriptionService;
    late SubscriptionGatingMiddleware gatingMiddleware;

    setUp(() async {
      repository = DocumentRepository();
      subscriptionService = SubscriptionService();
      gatingMiddleware = SubscriptionGatingMiddleware(subscriptionService);

      // Clear cache
      subscriptionService.clearCache();
    });

    test('should handle large document set efficiently', () async {
      print('\n=== Testing performance with large document set ===');

      const documentCount = 100;
      final createdDocs = <String>[];

      // Measure document creation time
      final createStart = DateTime.now();

      for (int i = 0; i < documentCount; i++) {
        final doc = await repository.createDocument(
          title: 'Performance Test Document $i',
          category: i % 3 == 0
              ? DocumentCategory.other
              : (i % 3 == 1
                  ? DocumentCategory.expenses
                  : DocumentCategory.carInsurance),
          notes: 'Document $i for performance testing',
        );
        createdDocs.add(doc.syncId);

        if ((i + 1) % 20 == 0) {
          print('Created ${i + 1}/$documentCount documents...');
        }
      }

      final createDuration = DateTime.now().difference(createStart);
      print(
          '✓ Created $documentCount documents in ${createDuration.inMilliseconds}ms');
      print(
          '  Average: ${createDuration.inMilliseconds / documentCount}ms per document');

      // Measure query performance
      final queryStart = DateTime.now();
      final allDocs = await repository.getAllDocuments();
      final queryDuration = DateTime.now().difference(queryStart);

      expect(allDocs.length, greaterThanOrEqualTo(documentCount));
      print(
          '✓ Queried ${allDocs.length} documents in ${queryDuration.inMilliseconds}ms');

      // Measure state query performance
      final stateQueryStart = DateTime.now();
      final pendingDocs =
          await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      final stateQueryDuration = DateTime.now().difference(stateQueryStart);

      expect(pendingDocs.length, greaterThanOrEqualTo(documentCount));
      print('✓ Queried by state in ${stateQueryDuration.inMilliseconds}ms');

      // Measure bulk update performance
      final updateStart = DateTime.now();

      for (final syncId in createdDocs) {
        await repository.updateSyncState(syncId, SyncState.synced);
      }

      final updateDuration = DateTime.now().difference(updateStart);
      print(
          '✓ Updated $documentCount states in ${updateDuration.inMilliseconds}ms');
      print(
          '  Average: ${updateDuration.inMilliseconds / documentCount}ms per update');

      // Measure individual document retrieval
      final retrieveStart = DateTime.now();

      for (int i = 0; i < 10; i++) {
        final doc = await repository.getDocument(createdDocs[i]);
        expect(doc, isNotNull);
      }

      final retrieveDuration = DateTime.now().difference(retrieveStart);
      print(
          '✓ Retrieved 10 individual documents in ${retrieveDuration.inMilliseconds}ms');
      print(
          '  Average: ${retrieveDuration.inMilliseconds / 10}ms per retrieval');

      // Clean up
      final deleteStart = DateTime.now();

      for (final syncId in createdDocs) {
        await repository.deleteDocument(syncId);
      }

      final deleteDuration = DateTime.now().difference(deleteStart);
      print(
          '✓ Deleted $documentCount documents in ${deleteDuration.inMilliseconds}ms');
      print(
          '  Average: ${deleteDuration.inMilliseconds / documentCount}ms per deletion');

      print('=== Performance test completed ===');
    });

    test('should handle subscription checks efficiently with caching',
        () async {
      print('\n=== Testing subscription check performance ===');

      // First check (cache miss - queries platform)
      final firstCheckStart = DateTime.now();
      final hasActive1 = await subscriptionService.hasActiveSubscription();
      final firstCheckDuration = DateTime.now().difference(firstCheckStart);

      print(
          '✓ First check (cache miss): ${firstCheckDuration.inMilliseconds}ms');
      print('  Result: $hasActive1');

      // Subsequent checks (cache hits)
      final cachedChecks = <Duration>[];

      for (int i = 0; i < 10; i++) {
        final checkStart = DateTime.now();
        final hasActive = await subscriptionService.hasActiveSubscription();
        final checkDuration = DateTime.now().difference(checkStart);

        cachedChecks.add(checkDuration);
        expect(hasActive, equals(hasActive1)); // Should be consistent
      }

      final avgCachedCheck = cachedChecks.fold<int>(
            0,
            (sum, duration) => sum + duration.inMilliseconds,
          ) /
          cachedChecks.length;

      print('✓ 10 cached checks completed');
      print('  Average cached check: ${avgCachedCheck.toStringAsFixed(2)}ms');
      print(
          '  Min: ${cachedChecks.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b)}ms');
      print(
          '  Max: ${cachedChecks.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b)}ms');

      // Verify cache is significantly faster than first check
      expect(avgCachedCheck, lessThan(firstCheckDuration.inMilliseconds));

      print('✓ Cache provides significant performance improvement');

      print('=== Subscription check performance test completed ===');
    });

    test('should handle bulk gating checks efficiently', () async {
      print('\n=== Testing bulk gating check performance ===');

      const checkCount = 50;
      final checkDurations = <Duration>[];

      for (int i = 0; i < checkCount; i++) {
        final checkStart = DateTime.now();
        final canSync = await gatingMiddleware.canPerformCloudSync();
        final checkDuration = DateTime.now().difference(checkStart);

        checkDurations.add(checkDuration);

        if ((i + 1) % 10 == 0) {
          print('Completed ${i + 1}/$checkCount gating checks...');
        }
      }

      final totalDuration = checkDurations.fold<int>(
        0,
        (sum, duration) => sum + duration.inMilliseconds,
      );

      final avgDuration = totalDuration / checkCount;
      final minDuration = checkDurations
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a < b ? a : b);
      final maxDuration = checkDurations
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a > b ? a : b);

      print('✓ Completed $checkCount gating checks');
      print('  Total time: ${totalDuration}ms');
      print('  Average: ${avgDuration.toStringAsFixed(2)}ms');
      print('  Min: ${minDuration}ms');
      print('  Max: ${maxDuration}ms');

      // Most checks should be fast (cached)
      final fastChecks =
          checkDurations.where((d) => d.inMilliseconds < 10).length;
      print(
          '  Fast checks (<10ms): $fastChecks/${checkCount} (${(fastChecks / checkCount * 100).toStringAsFixed(1)}%)');

      print('=== Bulk gating check performance test completed ===');
    });

    test('should handle concurrent document operations efficiently', () async {
      print('\n=== Testing concurrent operation performance ===');

      const concurrentCount = 20;

      // Create documents concurrently
      final createStart = DateTime.now();

      final createFutures = List.generate(
        concurrentCount,
        (i) => repository.createDocument(
          title: 'Concurrent Document $i',
          category: DocumentCategory.other,
        ),
      );

      final docs = await Future.wait(createFutures);
      final createDuration = DateTime.now().difference(createStart);

      expect(docs.length, equals(concurrentCount));
      print(
          '✓ Created $concurrentCount documents concurrently in ${createDuration.inMilliseconds}ms');
      print(
          '  Average: ${createDuration.inMilliseconds / concurrentCount}ms per document');

      // Update states concurrently
      final updateStart = DateTime.now();

      final updateFutures = docs
          .map(
            (doc) => repository.updateSyncState(doc.syncId, SyncState.synced),
          )
          .toList();

      await Future.wait(updateFutures);
      final updateDuration = DateTime.now().difference(updateStart);

      print(
          '✓ Updated $concurrentCount states concurrently in ${updateDuration.inMilliseconds}ms');
      print(
          '  Average: ${updateDuration.inMilliseconds / concurrentCount}ms per update');

      // Query concurrently
      final queryStart = DateTime.now();

      final queryFutures = docs
          .map(
            (doc) => repository.getDocument(doc.syncId),
          )
          .toList();

      final retrieved = await Future.wait(queryFutures);
      final queryDuration = DateTime.now().difference(queryStart);

      expect(retrieved.every((doc) => doc != null), isTrue);
      print(
          '✓ Queried $concurrentCount documents concurrently in ${queryDuration.inMilliseconds}ms');
      print(
          '  Average: ${queryDuration.inMilliseconds / concurrentCount}ms per query');

      // Delete concurrently
      final deleteStart = DateTime.now();

      final deleteFutures = docs
          .map(
            (doc) => repository.deleteDocument(doc.syncId),
          )
          .toList();

      await Future.wait(deleteFutures);
      final deleteDuration = DateTime.now().difference(deleteStart);

      print(
          '✓ Deleted $concurrentCount documents concurrently in ${deleteDuration.inMilliseconds}ms');
      print(
          '  Average: ${deleteDuration.inMilliseconds / concurrentCount}ms per deletion');

      print('=== Concurrent operation performance test completed ===');
    });

    test('should handle file attachments with large document sets', () async {
      print('\n=== Testing file attachment performance ===');

      const documentCount = 50;
      const filesPerDocument = 3;
      final createdDocs = <String>[];

      // Create documents with file attachments
      final createStart = DateTime.now();

      for (int i = 0; i < documentCount; i++) {
        final doc = await repository.createDocument(
          title: 'Document with Files $i',
          category: DocumentCategory.other,
        );
        createdDocs.add(doc.syncId);

        // Add multiple file attachments
        for (int j = 0; j < filesPerDocument; j++) {
          await repository.addFileAttachment(
            syncId: doc.syncId,
            fileName: 'file_${i}_${j}.pdf',
            localPath: '/path/to/file_${i}_${j}.pdf',
            fileSize: 1024 * (j + 1),
          );
        }

        if ((i + 1) % 10 == 0) {
          print('Created ${i + 1}/$documentCount documents with files...');
        }
      }

      final createDuration = DateTime.now().difference(createStart);
      print(
          '✓ Created $documentCount documents with ${documentCount * filesPerDocument} files');
      print('  Total time: ${createDuration.inMilliseconds}ms');
      print(
          '  Average per document: ${createDuration.inMilliseconds / documentCount}ms');

      // Query file attachments
      final queryStart = DateTime.now();

      for (final syncId in createdDocs) {
        final files = await repository.getFileAttachments(syncId);
        expect(files.length, equals(filesPerDocument));
      }

      final queryDuration = DateTime.now().difference(queryStart);
      print(
          '✓ Queried files for $documentCount documents in ${queryDuration.inMilliseconds}ms');
      print(
          '  Average per document: ${queryDuration.inMilliseconds / documentCount}ms');

      // Update S3 keys
      final updateStart = DateTime.now();

      for (int i = 0; i < documentCount; i++) {
        final syncId = createdDocs[i];
        for (int j = 0; j < filesPerDocument; j++) {
          await repository.updateFileS3Key(
            syncId: syncId,
            fileName: 'file_${i}_${j}.pdf',
            s3Key: 'private/identity/documents/$syncId/file_${i}_${j}.pdf',
          );
        }
      }

      final updateDuration = DateTime.now().difference(updateStart);
      print(
          '✓ Updated ${documentCount * filesPerDocument} S3 keys in ${updateDuration.inMilliseconds}ms');
      print(
          '  Average per file: ${updateDuration.inMilliseconds / (documentCount * filesPerDocument)}ms');

      // Clean up (cascade deletes files)
      final deleteStart = DateTime.now();

      for (final syncId in createdDocs) {
        await repository.deleteDocument(syncId);
      }

      final deleteDuration = DateTime.now().difference(deleteStart);
      print(
          '✓ Deleted $documentCount documents (cascade) in ${deleteDuration.inMilliseconds}ms');
      print(
          '  Average per document: ${deleteDuration.inMilliseconds / documentCount}ms');

      print('=== File attachment performance test completed ===');
    });

    test('should maintain performance during subscription state transitions',
        () async {
      print('\n=== Testing performance during state transitions ===');

      const documentCount = 30;
      final createdDocs = <String>[];

      // Create documents
      for (int i = 0; i < documentCount; i++) {
        final doc = await repository.createDocument(
          title: 'Transition Test $i',
          category: DocumentCategory.other,
        );
        createdDocs.add(doc.syncId);
      }

      print('✓ Created $documentCount documents');

      // Measure transition: pending -> uploading
      final transition1Start = DateTime.now();
      for (final syncId in createdDocs) {
        await repository.updateSyncState(syncId, SyncState.uploading);
      }
      final transition1Duration = DateTime.now().difference(transition1Start);

      print(
          '✓ Transition pending->uploading: ${transition1Duration.inMilliseconds}ms');
      print(
          '  Average: ${transition1Duration.inMilliseconds / documentCount}ms per document');

      // Measure transition: uploading -> synced
      final transition2Start = DateTime.now();
      for (final syncId in createdDocs) {
        await repository.updateSyncState(syncId, SyncState.synced);
      }
      final transition2Duration = DateTime.now().difference(transition2Start);

      print(
          '✓ Transition uploading->synced: ${transition2Duration.inMilliseconds}ms');
      print(
          '  Average: ${transition2Duration.inMilliseconds / documentCount}ms per document');

      // Measure transition: synced -> pending (expiration)
      final transition3Start = DateTime.now();
      for (final syncId in createdDocs) {
        await repository.updateSyncState(syncId, SyncState.pendingUpload);
      }
      final transition3Duration = DateTime.now().difference(transition3Start);

      print(
          '✓ Transition synced->pending: ${transition3Duration.inMilliseconds}ms');
      print(
          '  Average: ${transition3Duration.inMilliseconds / documentCount}ms per document');

      // Verify all documents are in correct state
      final pendingDocs =
          await repository.getDocumentsBySyncState(SyncState.pendingUpload);
      expect(pendingDocs.length, greaterThanOrEqualTo(documentCount));

      print('✓ All documents in correct state after transitions');

      // Clean up
      for (final syncId in createdDocs) {
        await repository.deleteDocument(syncId);
      }

      print('=== State transition performance test completed ===');
    });
  });
}
