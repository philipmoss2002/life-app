import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Document.dart';
import '../models/sync_state.dart';
import '../models/sync_event.dart';
import 'database_service.dart';
import 'log_service.dart';

/// Service for managing document sync states using sync identifiers
class SyncStateManager {
  final DatabaseService _databaseService;
  final LogService _logService;
  final StreamController<LocalSyncEvent> _syncEventController =
      StreamController<LocalSyncEvent>.broadcast();
  final List<SyncStateHistoryEntry> _stateHistory = [];

  SyncStateManager({
    required DatabaseService databaseService,
    required LogService logService,
  })  : _databaseService = databaseService,
        _logService = logService;

  /// Stream of sync state change events
  Stream<LocalSyncEvent> get syncStateEvents => _syncEventController.stream;

  /// Update sync state for a document identified by sync identifier
  ///
  /// [syncId] - The sync identifier of the document
  /// [newState] - The new sync state to set
  /// [metadata] - Optional metadata about the state change
  Future<void> updateSyncState(String syncId, SyncState newState,
      {Map<String, dynamic>? metadata}) async {
    try {
      _logService
          .log('Updating sync state for syncId: $syncId to ${newState.name}');

      // Find document by sync identifier
      final document = await _findDocumentBySyncId(syncId);
      if (document == null) {
        _logService.log('Document not found for syncId: $syncId',
            level: LogLevel.warning);
        return;
      }

      final oldState = SyncState.fromJson(document.syncState);

      // Only update if state actually changed
      if (oldState == newState) {
        _logService.log('Sync state unchanged for syncId: $syncId',
            level: LogLevel.debug);
        return;
      }

      // No need to check for duplicates when updating existing document's sync state
      // The syncId should remain the same, we're only updating the state

      // Update document sync state using the new syncId-based update method
      await _databaseService.updateDocumentBySyncId(syncId, {
        'syncState': newState.toJson(),
      });

      // Record state change in history
      _recordStateChange(syncId, oldState, newState, metadata);

      // Emit sync state change event
      _emitSyncStateEvent(
          syncId, document.syncId, oldState, newState, metadata);

      _logService.log(
          'Successfully updated sync state for syncId: $syncId from ${oldState.name} to ${newState.name}');
    } catch (e) {
      _logService.log('Failed to update sync state for syncId: $syncId: $e',
          level: LogLevel.error);

      // If the error is related to duplicate sync identifiers, log and rethrow
      if (e.toString().toLowerCase().contains('duplicate') &&
          e.toString().toLowerCase().contains('sync')) {
        _logService.log(
            'Duplicate sync ID error during state update for syncId: $syncId',
            level: LogLevel.error);
        _logService.log(
            'This indicates a validation issue, not an actual duplicate',
            level: LogLevel.error);
      }

      rethrow;
    }
  }

  /// Get current sync state for a document by sync identifier
  Future<SyncState?> getSyncState(String syncId) async {
    try {
      final document = await _findDocumentBySyncId(syncId);
      if (document == null) {
        return null;
      }
      return SyncState.fromJson(document.syncState);
    } catch (e) {
      _logService.log('Failed to get sync state for syncId: $syncId: $e',
          level: LogLevel.error);
      return null;
    }
  }

  /// Query documents by sync state, returning their sync identifiers
  Future<List<String>> getDocumentsBySyncState(SyncState state) async {
    try {
      final documents = await _databaseService.getAllDocuments();
      final filteredDocuments = documents.where((doc) {
        try {
          final docState = SyncState.fromJson(doc.syncState);
          return docState == state;
        } catch (e) {
          _logService.log(
              'Invalid sync state for document ${doc.syncId}: ${doc.syncState}',
              level: LogLevel.warning);
          return false;
        }
      }).toList();

      // Return sync identifiers of matching documents
      return filteredDocuments
          .where((doc) => doc.syncId.isNotEmpty)
          .map((doc) => doc.syncId)
          .toList();
    } catch (e) {
      _logService.log(
          'Failed to query documents by sync state: ${state.name}: $e',
          level: LogLevel.error);
      return [];
    }
  }

  /// Get sync state history for a document by sync identifier
  List<SyncStateHistoryEntry> getSyncStateHistory(String syncId) {
    return _stateHistory.where((entry) => entry.syncId == syncId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get all sync state history entries (for debugging)
  List<SyncStateHistoryEntry> getAllSyncStateHistory() {
    return List.unmodifiable(_stateHistory);
  }

  /// Clear old history entries (keep last 100 per document)
  void cleanupHistory() {
    final syncIds = _stateHistory.map((e) => e.syncId).toSet();

    for (final syncId in syncIds) {
      final entries = _stateHistory.where((e) => e.syncId == syncId).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (entries.length > 100) {
        final toRemove = entries.skip(100);
        _stateHistory.removeWhere(
            (entry) => entry.syncId == syncId && toRemove.contains(entry));
      }
    }
  }

  /// Handle document deletion - preserve sync identifier for remote deletion
  Future<void> markForDeletion(String syncId,
      {Map<String, dynamic>? metadata}) async {
    await updateSyncState(syncId, SyncState.pendingDeletion,
        metadata: metadata);
  }

  /// Batch update sync states for multiple documents
  Future<void> batchUpdateSyncStates(Map<String, SyncState> updates) async {
    for (final entry in updates.entries) {
      await updateSyncState(entry.key, entry.value);
    }
  }

  /// Find document by sync identifier
  Future<Document?> _findDocumentBySyncId(String syncId) async {
    final documents = await _databaseService.getAllDocuments();
    try {
      return documents.firstWhere((doc) => doc.syncId == syncId);
    } catch (e) {
      return null;
    }
  }

  /// Record state change in history
  void _recordStateChange(String syncId, SyncState oldState, SyncState newState,
      Map<String, dynamic>? metadata) {
    final historyEntry = SyncStateHistoryEntry(
      syncId: syncId,
      oldState: oldState,
      newState: newState,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _stateHistory.add(historyEntry);

    // Keep history manageable
    if (_stateHistory.length > 1000) {
      cleanupHistory();
    }
  }

  /// Emit sync state change event
  void _emitSyncStateEvent(
    String syncId,
    String documentId,
    SyncState oldState,
    SyncState newState,
    Map<String, dynamic>? metadata,
  ) {
    if (_syncEventController.isClosed) return;

    final event = LocalSyncEvent(
      id: const Uuid().v4(),
      eventType: SyncEventType.stateChanged.value,
      entityType: 'document',
      entityId: documentId,
      syncId: syncId,
      message:
          'Sync state changed from ${oldState.displayName} to ${newState.displayName}',
      timestamp: amplify_core.TemporalDateTime.now(),
      metadata: {
        'oldState': oldState.toJson(),
        'newState': newState.toJson(),
        if (metadata != null) ...metadata,
      },
    );

    _syncEventController.add(event);
  }

  /// Dispose resources
  void dispose() {
    _syncEventController.close();
  }
}

/// Represents a sync state change in history
class SyncStateHistoryEntry {
  final String syncId;
  final SyncState oldState;
  final SyncState newState;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const SyncStateHistoryEntry({
    required this.syncId,
    required this.oldState,
    required this.newState,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() {
    return 'SyncStateHistoryEntry{syncId: $syncId, ${oldState.name} -> ${newState.name}, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncStateHistoryEntry &&
        other.syncId == syncId &&
        other.oldState == oldState &&
        other.newState == newState &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return syncId.hashCode ^
        oldState.hashCode ^
        newState.hashCode ^
        timestamp.hashCode;
  }
}
