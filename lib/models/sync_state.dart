/// Sync state for documents
///
/// Indicates the current synchronization status of a document.
enum SyncState {
  /// File is synced (uploaded and available)
  synced,

  /// File needs to be uploaded
  pendingUpload,

  /// File needs to be downloaded
  pendingDownload,

  /// Upload in progress
  uploading,

  /// Download in progress
  downloading,

  /// Sync error occurred
  error,
}

/// Extension methods for SyncState
extension SyncStateExtension on SyncState {
  /// Check if the document is in a pending state
  bool get isPending =>
      this == SyncState.pendingUpload || this == SyncState.pendingDownload;

  /// Check if the document is currently syncing
  bool get isSyncing =>
      this == SyncState.uploading || this == SyncState.downloading;

  /// Check if the document is synced
  bool get isSynced => this == SyncState.synced;

  /// Check if there was an error
  bool get hasError => this == SyncState.error;

  /// Get a human-readable description
  String get description {
    switch (this) {
      case SyncState.synced:
        return 'Synced';
      case SyncState.pendingUpload:
        return 'Pending Upload';
      case SyncState.pendingDownload:
        return 'Pending Download';
      case SyncState.uploading:
        return 'Uploading...';
      case SyncState.downloading:
        return 'Downloading...';
      case SyncState.error:
        return 'Sync Error';
    }
  }
}
