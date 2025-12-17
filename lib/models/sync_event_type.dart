enum SyncEventType {
  syncStarted,
  syncCompleted,
  syncFailed,
  documentUploaded,
  documentDownloaded,
  conflictDetected,
  stateChanged,
}

extension SyncEventTypeExtension on SyncEventType {
  String get value {
    switch (this) {
      case SyncEventType.syncStarted:
        return 'SYNC_STARTED';
      case SyncEventType.syncCompleted:
        return 'SYNC_COMPLETED';
      case SyncEventType.syncFailed:
        return 'SYNC_FAILED';
      case SyncEventType.documentUploaded:
        return 'DOCUMENT_UPLOADED';
      case SyncEventType.documentDownloaded:
        return 'DOCUMENT_DOWNLOADED';
      case SyncEventType.conflictDetected:
        return 'CONFLICT_DETECTED';
      case SyncEventType.stateChanged:
        return 'STATE_CHANGED';
    }
  }
}
