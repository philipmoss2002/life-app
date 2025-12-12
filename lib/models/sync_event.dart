import 'sync_state.dart';

/// Types of sync events that can occur
enum SyncEventType {
  /// Sync started
  syncStarted,

  /// Sync completed successfully
  syncCompleted,

  /// Sync failed
  syncFailed,

  /// Document uploaded
  documentUploaded,

  /// Document downloaded
  documentDownloaded,

  /// File uploaded
  fileUploaded,

  /// File downloaded
  fileDownloaded,

  /// Conflict detected
  conflictDetected,

  /// Sync state changed
  stateChanged,
}

/// Represents a synchronization event for event streaming
class SyncEvent {
  final String id;
  final SyncEventType type;
  final String? documentId;
  final String? fileId;
  final SyncState? newState;
  final String? message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  SyncEvent({
    required this.id,
    required this.type,
    this.documentId,
    this.fileId,
    this.newState,
    this.message,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'documentId': documentId,
      'fileId': fileId,
      'newState': newState?.toJson(),
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory SyncEvent.fromMap(Map<String, dynamic> map) {
    return SyncEvent(
      id: map['id'],
      type: SyncEventType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => SyncEventType.stateChanged,
      ),
      documentId: map['documentId'],
      fileId: map['fileId'],
      newState:
          map['newState'] != null ? SyncState.fromJson(map['newState']) : null,
      message: map['message'],
      timestamp: DateTime.parse(map['timestamp']),
      metadata: map['metadata'],
    );
  }

  SyncEvent copyWith({
    String? id,
    SyncEventType? type,
    String? documentId,
    String? fileId,
    SyncState? newState,
    String? message,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return SyncEvent(
      id: id ?? this.id,
      type: type ?? this.type,
      documentId: documentId ?? this.documentId,
      fileId: fileId ?? this.fileId,
      newState: newState ?? this.newState,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
}
