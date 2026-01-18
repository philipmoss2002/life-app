import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('SyncState', () {
    test('has all expected values', () {
      expect(SyncState.values.length, equals(6));
      expect(SyncState.values, contains(SyncState.synced));
      expect(SyncState.values, contains(SyncState.pendingUpload));
      expect(SyncState.values, contains(SyncState.pendingDownload));
      expect(SyncState.values, contains(SyncState.uploading));
      expect(SyncState.values, contains(SyncState.downloading));
      expect(SyncState.values, contains(SyncState.error));
    });

    test('isPending returns true for pending states', () {
      expect(SyncState.pendingUpload.isPending, isTrue);
      expect(SyncState.pendingDownload.isPending, isTrue);
      expect(SyncState.synced.isPending, isFalse);
      expect(SyncState.uploading.isPending, isFalse);
      expect(SyncState.downloading.isPending, isFalse);
      expect(SyncState.error.isPending, isFalse);
    });

    test('isSyncing returns true for active sync states', () {
      expect(SyncState.uploading.isSyncing, isTrue);
      expect(SyncState.downloading.isSyncing, isTrue);
      expect(SyncState.synced.isSyncing, isFalse);
      expect(SyncState.pendingUpload.isSyncing, isFalse);
      expect(SyncState.pendingDownload.isSyncing, isFalse);
      expect(SyncState.error.isSyncing, isFalse);
    });

    test('isSynced returns true only for synced state', () {
      expect(SyncState.synced.isSynced, isTrue);
      expect(SyncState.pendingUpload.isSynced, isFalse);
      expect(SyncState.pendingDownload.isSynced, isFalse);
      expect(SyncState.uploading.isSynced, isFalse);
      expect(SyncState.downloading.isSynced, isFalse);
      expect(SyncState.error.isSynced, isFalse);
    });

    test('hasError returns true only for error state', () {
      expect(SyncState.error.hasError, isTrue);
      expect(SyncState.synced.hasError, isFalse);
      expect(SyncState.pendingUpload.hasError, isFalse);
      expect(SyncState.pendingDownload.hasError, isFalse);
      expect(SyncState.uploading.hasError, isFalse);
      expect(SyncState.downloading.hasError, isFalse);
    });

    test('description returns human-readable text', () {
      expect(SyncState.synced.description, equals('Synced'));
      expect(SyncState.pendingUpload.description, equals('Pending Upload'));
      expect(SyncState.pendingDownload.description, equals('Pending Download'));
      expect(SyncState.uploading.description, equals('Uploading...'));
      expect(SyncState.downloading.description, equals('Downloading...'));
      expect(SyncState.error.description, equals('Sync Error'));
    });

    test('name property returns enum name', () {
      expect(SyncState.synced.name, equals('synced'));
      expect(SyncState.pendingUpload.name, equals('pendingUpload'));
      expect(SyncState.pendingDownload.name, equals('pendingDownload'));
      expect(SyncState.uploading.name, equals('uploading'));
      expect(SyncState.downloading.name, equals('downloading'));
      expect(SyncState.error.name, equals('error'));
    });
  });
}
