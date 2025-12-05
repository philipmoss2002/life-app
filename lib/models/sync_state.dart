/// Represents the synchronization state of a document or file attachment
enum SyncState {
  /// Fully synchronized with remote storage
  synced,

  /// Changes waiting to be synchronized
  pending,

  /// Currently synchronizing
  syncing,

  /// Conflict detected between local and remote versions
  conflict,

  /// Sync error occurred
  error,

  /// Not yet synchronized (new item or sync disabled)
  notSynced;

  /// Convert SyncState to string for storage
  String toJson() => name;

  /// Create SyncState from string
  static SyncState fromJson(String json) {
    return SyncState.values.firstWhere(
      (state) => state.name == json,
      orElse: () => SyncState.notSynced,
    );
  }
}
