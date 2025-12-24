/// Synchronization state enum for documents
enum SyncState {
  /// Document has not been synced to cloud
  notSynced,

  /// Document is pending sync
  pending,

  /// Document is currently being synced
  syncing,

  /// Document has been successfully synced
  synced,

  /// Document sync failed
  error,

  /// Document has a conflict that needs resolution
  conflict,

  /// Document is pending deletion from cloud
  pendingDeletion;

  /// Convert enum to JSON string
  String toJson() {
    switch (this) {
      case SyncState.notSynced:
        return 'notSynced';
      case SyncState.pending:
        return 'pending';
      case SyncState.syncing:
        return 'syncing';
      case SyncState.synced:
        return 'synced';
      case SyncState.error:
        return 'error';
      case SyncState.conflict:
        return 'conflict';
      case SyncState.pendingDeletion:
        return 'pendingDeletion';
    }
  }

  /// Create enum from JSON string
  static SyncState fromJson(String json) {
    switch (json) {
      case 'notSynced':
        return SyncState.notSynced;
      case 'pending':
        return SyncState.pending;
      case 'syncing':
        return SyncState.syncing;
      case 'synced':
        return SyncState.synced;
      case 'error':
        return SyncState.error;
      case 'conflict':
        return SyncState.conflict;
      case 'pendingDeletion':
        return SyncState.pendingDeletion;
      default:
        return SyncState.notSynced;
    }
  }

  /// Get display name for the sync state
  String get displayName {
    switch (this) {
      case SyncState.notSynced:
        return 'Not Synced';
      case SyncState.pending:
        return 'Pending';
      case SyncState.syncing:
        return 'Syncing';
      case SyncState.synced:
        return 'Synced';
      case SyncState.error:
        return 'Error';
      case SyncState.conflict:
        return 'Conflict';
      case SyncState.pendingDeletion:
        return 'Deleting';
    }
  }

  /// Check if the state indicates sync is in progress
  bool get isSyncing => this == SyncState.syncing;

  /// Check if the state indicates successful sync
  bool get isSynced => this == SyncState.synced;

  /// Check if the state indicates an error
  bool get hasError => this == SyncState.error;

  /// Check if the state indicates a conflict
  bool get hasConflict => this == SyncState.conflict;
}
