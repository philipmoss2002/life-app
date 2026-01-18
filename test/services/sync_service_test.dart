import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/sync_service.dart';

void main() {
  group('SyncService', () {
    late SyncService syncService;

    setUp(() {
      syncService = SyncService();
    });

    test('should be a singleton', () {
      final instance1 = SyncService();
      final instance2 = SyncService();
      expect(instance1, same(instance2));
    });

    test('should have syncStatusStream', () {
      expect(syncService.syncStatusStream, isA<Stream<SyncStatus>>());
    });

    test('should have isSyncing getter', () {
      expect(syncService.isSyncing, isA<bool>());
      expect(syncService.isSyncing, isFalse); // Initially not syncing
    });

    group('SyncException', () {
      test('should create exception with message', () {
        final exception = SyncException('Sync failed');
        expect(exception.message, equals('Sync failed'));
        expect(exception.toString(), equals('SyncException: Sync failed'));
      });
    });

    group('SyncStatus', () {
      test('should have all required values', () {
        expect(SyncStatus.values, contains(SyncStatus.idle));
        expect(SyncStatus.values, contains(SyncStatus.syncing));
        expect(SyncStatus.values, contains(SyncStatus.completed));
        expect(SyncStatus.values, contains(SyncStatus.error));
      });
    });

    group('Method signatures', () {
      test('performSync should have correct signature', () {
        expect(
          syncService.performSync,
          isA<Function>(),
        );
      });

      test('syncDocument should have correct signature', () {
        expect(
          syncService.syncDocument,
          isA<Function>(),
        );
      });

      test('uploadDocumentFiles should have correct signature', () {
        expect(
          syncService.uploadDocumentFiles,
          isA<Function>(),
        );
      });

      test('downloadDocumentFiles should have correct signature', () {
        expect(
          syncService.downloadDocumentFiles,
          isA<Function>(),
        );
      });

      test('triggerSync should have correct signature', () {
        expect(
          syncService.triggerSync,
          isA<Function>(),
        );
      });

      test('syncOnAppLaunch should have correct signature', () {
        expect(
          syncService.syncOnAppLaunch,
          isA<Function>(),
        );
      });

      test('syncOnDocumentChange should have correct signature', () {
        expect(
          syncService.syncOnDocumentChange,
          isA<Function>(),
        );
      });

      test('syncOnNetworkRestored should have correct signature', () {
        expect(
          syncService.syncOnNetworkRestored,
          isA<Function>(),
        );
      });

      test('dispose should have correct signature', () {
        expect(
          syncService.dispose,
          isA<Function>(),
        );
      });
    });

    group('Sync triggers', () {
      test('triggerSync should accept debounce delay parameter', () {
        expect(
          () => syncService.triggerSync(
              debounceDelay: const Duration(seconds: 5)),
          returnsNormally,
        );
      });

      test('syncOnDocumentChange should accept syncId parameter', () {
        expect(
          () => syncService.syncOnDocumentChange('test-sync-id'),
          returnsNormally,
        );
      });

      test('syncOnNetworkRestored should be callable', () {
        expect(
          () => syncService.syncOnNetworkRestored(),
          returnsNormally,
        );
      });
    });
  });
}
