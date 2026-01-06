import 'package:flutter_test/flutter_test.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;

import '../../lib/services/sync_state_manager.dart';
import '../../lib/services/database_service.dart';
import '../../lib/services/log_service.dart';
import '../../lib/models/Document.dart';
import '../../lib/models/sync_state.dart';
import '../../lib/models/sync_event.dart';
import '../test_helpers.dart';

void main() {
  group('SyncStateManager', () {
    late SyncStateManager syncStateManager;

    setUpAll(() {
      setupTestDatabase();
    });

    setUp(() {
      syncStateManager = SyncStateManager(
        databaseService: DatabaseService.instance,
        logService: LogService(),
      );
    });

    tearDown(() {
      syncStateManager.dispose();
    });

    group('SyncStateHistoryEntry', () {
      test('should create history entry correctly', () {
        // Arrange
        const syncId = 'test-sync-id-123';
        final timestamp = DateTime.now();
        final metadata = {'test': 'data'};

        // Act
        final entry = SyncStateHistoryEntry(
          syncId: syncId,
          oldState: SyncState.notSynced,
          newState: SyncState.syncing,
          timestamp: timestamp,
          metadata: metadata,
        );

        // Assert
        expect(entry.syncId, equals(syncId));
        expect(entry.oldState, equals(SyncState.notSynced));
        expect(entry.newState, equals(SyncState.syncing));
        expect(entry.timestamp, equals(timestamp));
        expect(entry.metadata, equals(metadata));
      });

      test('should have correct string representation', () {
        // Arrange
        const syncId = 'test-sync-id-123';
        final timestamp = DateTime.now();

        final entry = SyncStateHistoryEntry(
          syncId: syncId,
          oldState: SyncState.notSynced,
          newState: SyncState.syncing,
          timestamp: timestamp,
        );

        // Act
        final result = entry.toString();

        // Assert
        expect(result, contains(syncId));
        expect(result, contains('notSynced'));
        expect(result, contains('syncing'));
        expect(result, contains(timestamp.toString()));
      });

      test('should implement equality correctly', () {
        // Arrange
        const syncId = 'test-sync-id-123';
        final timestamp = DateTime.now();

        final entry1 = SyncStateHistoryEntry(
          syncId: syncId,
          oldState: SyncState.notSynced,
          newState: SyncState.syncing,
          timestamp: timestamp,
        );

        final entry2 = SyncStateHistoryEntry(
          syncId: syncId,
          oldState: SyncState.notSynced,
          newState: SyncState.syncing,
          timestamp: timestamp,
        );

        final entry3 = SyncStateHistoryEntry(
          syncId: 'different-sync-id',
          oldState: SyncState.notSynced,
          newState: SyncState.syncing,
          timestamp: timestamp,
        );

        // Act & Assert
        expect(entry1, equals(entry2));
        expect(entry1, isNot(equals(entry3)));
        expect(entry1.hashCode, equals(entry2.hashCode));
      });
    });

    group('sync state events', () {
      test('should provide sync state events stream', () {
        // Act
        final stream = syncStateManager.syncStateEvents;

        // Assert
        expect(stream, isA<Stream<SyncEvent>>());
      });
    });

    group('history management', () {
      test('should return empty history for non-existent sync id', () {
        // Act
        final history = syncStateManager.getSyncStateHistory('non-existent');

        // Assert
        expect(history, isEmpty);
      });

      test('should return all history entries', () {
        // Act
        final allHistory = syncStateManager.getAllSyncStateHistory();

        // Assert
        expect(allHistory, isA<List<SyncStateHistoryEntry>>());
      });

      test('should clean up history without errors', () {
        // Act & Assert - should not throw
        expect(() => syncStateManager.cleanupHistory(), returnsNormally);
      });
    });

    group('batch operations', () {
      test('should handle empty batch updates', () async {
        // Act & Assert - should not throw
        await expectLater(
          syncStateManager.batchUpdateSyncStates({}),
          completes,
        );
      });
    });

    group('error handling', () {
      test('should handle getSyncState for non-existent document', () async {
        // Act
        final result =
            await syncStateManager.getSyncState('non-existent-sync-id');

        // Assert
        expect(result, isNull);
      });

      test('should handle getDocumentsBySyncState gracefully', () async {
        // Act
        final result =
            await syncStateManager.getDocumentsBySyncState(SyncState.synced);

        // Assert
        expect(result, isA<List<String>>());
      });
    });
  });
}
