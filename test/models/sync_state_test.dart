import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/models/sync_state.dart';

void main() {
  group('SyncState Enum Tests', () {
    test('SyncState should have all expected values', () {
      expect(SyncState.values.length, 6);
      expect(SyncState.values.contains(SyncState.synced), true);
      expect(SyncState.values.contains(SyncState.pending), true);
      expect(SyncState.values.contains(SyncState.syncing), true);
      expect(SyncState.values.contains(SyncState.conflict), true);
      expect(SyncState.values.contains(SyncState.error), true);
      expect(SyncState.values.contains(SyncState.notSynced), true);
    });

    test('SyncState toJson should return correct string', () {
      expect(SyncState.synced.toJson(), 'synced');
      expect(SyncState.pending.toJson(), 'pending');
      expect(SyncState.syncing.toJson(), 'syncing');
      expect(SyncState.conflict.toJson(), 'conflict');
      expect(SyncState.error.toJson(), 'error');
      expect(SyncState.notSynced.toJson(), 'notSynced');
    });

    test('SyncState fromJson should parse correct values', () {
      expect(SyncState.fromJson('synced'), SyncState.synced);
      expect(SyncState.fromJson('pending'), SyncState.pending);
      expect(SyncState.fromJson('syncing'), SyncState.syncing);
      expect(SyncState.fromJson('conflict'), SyncState.conflict);
      expect(SyncState.fromJson('error'), SyncState.error);
      expect(SyncState.fromJson('notSynced'), SyncState.notSynced);
    });

    test('SyncState fromJson should return notSynced for invalid values', () {
      expect(SyncState.fromJson('invalid'), SyncState.notSynced);
      expect(SyncState.fromJson(''), SyncState.notSynced);
      expect(SyncState.fromJson('unknown'), SyncState.notSynced);
    });

    test('SyncState round trip serialization should work', () {
      for (final state in SyncState.values) {
        final json = state.toJson();
        final parsed = SyncState.fromJson(json);
        expect(parsed, state);
      }
    });
  });
}
