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

/// Model representing a synchronization event
class SyncEvent {
  final String id;
  final String eventType;
  final String entityType;
  final String entityId;
  final String message;
  final amplify_core.TemporalDateTime timestamp;

  SyncEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.message,
    required this.timestamp,
  });

  /// Create SyncEvent from JSON
  factory SyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEvent(
      id: json['id'] as String,
      eventType: json['eventType'] as String,
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      message: json['message'] as String,
      timestamp:
          amplify_core.TemporalDateTime.fromString(json['timestamp'] as String),
    );
  }

  /// Convert SyncEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventType': eventType,
      'entityType': entityType,
      'entityId': entityId,
      'message': message,
      'timestamp': timestamp.format(),
    };
  }

  @override
  String toString() {
    return 'SyncEvent{id: $id, eventType: $eventType, entityType: $entityType, entityId: $entityId, message: $message, timestamp: ${timestamp.format()}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncEvent &&
        other.id == id &&
        other.eventType == eventType &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.message == message &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        eventType.hashCode ^
        entityType.hashCode ^
        entityId.hashCode ^
        message.hashCode ^
        timestamp.hashCode;
  }
}
