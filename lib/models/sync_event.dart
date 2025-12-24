import 'package:amplify_core/amplify_core.dart' as amplify_core;

/// Enum representing different types of sync events
enum SyncEventType {
  syncStarted('sync_started'),
  syncCompleted('sync_completed'),
  syncFailed('sync_failed'),
  documentUploaded('document_uploaded'),
  documentDownloaded('document_downloaded'),
  documentDeleted('document_deleted'),
  conflictDetected('conflict_detected'),
  stateChanged('state_changed');

  const SyncEventType(this.value);
  final String value;
}

/// Model representing a synchronization event (local/custom implementation)
/// Note: This is different from the generated SyncEvent model used for DynamoDB
class LocalSyncEvent {
  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String? syncId; // Sync identifier for document-related events
  final String message;
  final amplify_core.TemporalDateTime timestamp;
  final Map<String, dynamic>? metadata; // Additional event metadata

  LocalSyncEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    this.syncId,
    required this.message,
    required this.timestamp,
    this.metadata,
  });

  /// Create LocalSyncEvent from JSON
  factory LocalSyncEvent.fromJson(Map<String, dynamic> json) {
    return LocalSyncEvent(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      syncId: json['syncId'] as String?,
      message: json['message'] as String,
      timestamp:
          amplify_core.TemporalDateTime.fromString(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Convert LocalSyncEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventType': eventType,
      'entityType': entityType,
      'entityId': entityId,
      if (syncId != null) 'syncId': syncId,
      'message': message,
      'timestamp': timestamp.format(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a copy of this event with updated fields
  LocalSyncEvent copyWith({
    String? id,
    String? eventType,
    String? entityType,
    String? entityId,
    String? syncId,
    String? message,
    amplify_core.TemporalDateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return LocalSyncEvent(
        id: id ?? this.id,
        eventType: eventType ?? this.eventType,
        entityType: entityType ?? this.entityType,
        entityId: entityId ?? this.entityId,
        syncId: syncId ?? this.syncId,
        message: message ?? this.message,
        timestamp: timestamp ?? this.timestamp,
        metadata: metadata ?? this.metadata);
  }

  @override
  String toString() {
    return 'LocalSyncEvent{id: $id, eventType: $eventType, entityType: $entityType, entityId: $entityId, syncId: $syncId, message: $message, timestamp: ${timestamp.format()}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalSyncEvent &&
        other.id == id &&
        other.eventType == eventType &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.syncId == syncId &&
        other.message == message &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        eventType.hashCode ^
        entityType.hashCode ^
        entityId.hashCode ^
        (syncId?.hashCode ?? 0) ^
        message.hashCode ^
        timestamp.hashCode;
  }
}
