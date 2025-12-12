import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_state.dart';

/// Model representing a sync analytics event
class SyncAnalyticsEvent {
  final String id;
  final DateTime timestamp;
  final AnalyticsSyncEventType type;
  final bool success;
  final int? latencyMs;
  final String? errorMessage;
  final String? documentId;

  SyncAnalyticsEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.success,
    this.latencyMs,
    this.errorMessage,
    this.documentId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.toString(),
        'success': success,
        'latencyMs': latencyMs,
        'errorMessage': errorMessage,
        'documentId': documentId,
      };
}

/// Model representing authentication analytics event
class AuthAnalyticsEvent {
  final String id;
  final DateTime timestamp;
  final AuthEventType type;
  final bool success;
  final String? errorMessage;

  AuthAnalyticsEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.toString(),
        'success': success,
        'errorMessage': errorMessage,
      };
}

/// Model representing conflict analytics event
class ConflictAnalyticsEvent {
  final String id;
  final DateTime timestamp;
  final String documentId;
  final String conflictType;
  final String? resolutionStrategy;
  final DateTime? resolvedAt;

  ConflictAnalyticsEvent({
    required this.id,
    required this.timestamp,
    required this.documentId,
    required this.conflictType,
    this.resolutionStrategy,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'documentId': documentId,
        'conflictType': conflictType,
        'resolutionStrategy': resolutionStrategy,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };
}

/// Model representing storage analytics
class StorageAnalytics {
  final DateTime timestamp;
  final int usedBytes;
  final int quotaBytes;
  final double usagePercentage;
  final int documentCount;
  final int fileCount;

  StorageAnalytics({
    required this.timestamp,
    required this.usedBytes,
    required this.quotaBytes,
    required this.usagePercentage,
    required this.documentCount,
    required this.fileCount,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'usedBytes': usedBytes,
        'quotaBytes': quotaBytes,
        'usagePercentage': usagePercentage,
        'documentCount': documentCount,
        'fileCount': fileCount,
      };
}

/// Enum for analytics sync event types
enum AnalyticsSyncEventType {
  documentUpload,
  documentDownload,
  documentUpdate,
  documentDelete,
  fileUpload,
  fileDownload,
  fileDelete,
}

/// Enum for authentication event types
enum AuthEventType {
  signUp,
  signIn,
  signOut,
  passwordReset,
  tokenRefresh,
}

/// Analytics and monitoring service
/// Tracks sync success/failure, latency, storage usage, authentication, and conflicts
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Event storage
  final List<SyncAnalyticsEvent> _syncEvents = [];
  final List<AuthAnalyticsEvent> _authEvents = [];
  final List<ConflictAnalyticsEvent> _conflictEvents = [];
  final List<StorageAnalytics> _storageSnapshots = [];

  // Metrics
  int _totalSyncAttempts = 0;
  int _successfulSyncs = 0;
  int _failedSyncs = 0;
  final List<int> _syncLatencies = [];
  int _totalAuthAttempts = 0;
  int _failedAuthAttempts = 0;
  int _totalConflicts = 0;
  int _resolvedConflicts = 0;

  // Event streaming
  final StreamController<SyncAnalyticsEvent> _syncEventController =
      StreamController<SyncAnalyticsEvent>.broadcast();
  final StreamController<AuthAnalyticsEvent> _authEventController =
      StreamController<AuthAnalyticsEvent>.broadcast();
  final StreamController<ConflictAnalyticsEvent> _conflictEventController =
      StreamController<ConflictAnalyticsEvent>.broadcast();

  /// Stream of sync analytics events
  Stream<SyncAnalyticsEvent> get syncEventStream => _syncEventController.stream;

  /// Stream of auth analytics events
  Stream<AuthAnalyticsEvent> get authEventStream => _authEventController.stream;

  /// Stream of conflict analytics events
  Stream<ConflictAnalyticsEvent> get conflictEventStream =>
      _conflictEventController.stream;

  /// Track a sync event
  Future<void> trackSyncEvent({
    required AnalyticsSyncEventType type,
    required bool success,
    int? latencyMs,
    String? errorMessage,
    String? documentId,
  }) async {
    _totalSyncAttempts++;

    if (success) {
      _successfulSyncs++;
    } else {
      _failedSyncs++;
    }

    if (latencyMs != null) {
      _syncLatencies.add(latencyMs);
    }

    final event = SyncAnalyticsEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      success: success,
      latencyMs: latencyMs,
      errorMessage: errorMessage,
      documentId: documentId,
    );

    _syncEvents.add(event);
    _syncEventController.add(event);

    // Persist metrics
    await _persistMetrics();

    safePrint(
        'Analytics: Sync event tracked - ${type.toString()}, success: $success');
  }

  /// Track an authentication event
  Future<void> trackAuthEvent({
    required AuthEventType type,
    required bool success,
    String? errorMessage,
  }) async {
    _totalAuthAttempts++;

    if (!success) {
      _failedAuthAttempts++;
    }

    final event = AuthAnalyticsEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      success: success,
      errorMessage: errorMessage,
    );

    _authEvents.add(event);
    _authEventController.add(event);

    // Persist metrics
    await _persistMetrics();

    safePrint(
        'Analytics: Auth event tracked - ${type.toString()}, success: $success');
  }

  /// Track a conflict event
  Future<void> trackConflictDetected({
    required String documentId,
    required String conflictType,
  }) async {
    _totalConflicts++;

    final event = ConflictAnalyticsEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      documentId: documentId,
      conflictType: conflictType,
    );

    _conflictEvents.add(event);
    _conflictEventController.add(event);

    // Persist metrics
    await _persistMetrics();

    safePrint('Analytics: Conflict detected for document $documentId');
  }

  /// Track a conflict resolution
  Future<void> trackConflictResolved({
    required String conflictId,
    required String resolutionStrategy,
  }) async {
    _resolvedConflicts++;

    // Find the conflict event and update it
    final index = _conflictEvents.indexWhere((e) => e.id == conflictId);
    if (index != -1) {
      final updatedEvent = ConflictAnalyticsEvent(
        id: _conflictEvents[index].id,
        timestamp: _conflictEvents[index].timestamp,
        documentId: _conflictEvents[index].documentId,
        conflictType: _conflictEvents[index].conflictType,
        resolutionStrategy: resolutionStrategy,
        resolvedAt: DateTime.now(),
      );

      _conflictEvents[index] = updatedEvent;
      _conflictEventController.add(updatedEvent);
    }

    // Persist metrics
    await _persistMetrics();

    safePrint('Analytics: Conflict resolved with strategy $resolutionStrategy');
  }

  /// Track storage usage snapshot
  Future<void> trackStorageUsage({
    required int usedBytes,
    required int quotaBytes,
    required int documentCount,
    required int fileCount,
  }) async {
    final snapshot = StorageAnalytics(
      timestamp: DateTime.now(),
      usedBytes: usedBytes,
      quotaBytes: quotaBytes,
      usagePercentage: quotaBytes > 0 ? (usedBytes / quotaBytes) * 100 : 0,
      documentCount: documentCount,
      fileCount: fileCount,
    );

    _storageSnapshots.add(snapshot);

    // Keep only last 100 snapshots
    if (_storageSnapshots.length > 100) {
      _storageSnapshots.removeAt(0);
    }

    safePrint(
        'Analytics: Storage snapshot - ${snapshot.usagePercentage.toStringAsFixed(2)}% used');
  }

  /// Get sync success rate
  double getSyncSuccessRate() {
    if (_totalSyncAttempts == 0) return 0.0;
    return (_successfulSyncs / _totalSyncAttempts) * 100;
  }

  /// Get average sync latency in milliseconds
  double getAverageSyncLatency() {
    if (_syncLatencies.isEmpty) return 0.0;
    final sum = _syncLatencies.reduce((a, b) => a + b);
    return sum / _syncLatencies.length;
  }

  /// Get authentication failure rate
  double getAuthFailureRate() {
    if (_totalAuthAttempts == 0) return 0.0;
    return (_failedAuthAttempts / _totalAuthAttempts) * 100;
  }

  /// Get conflict resolution rate
  double getConflictResolutionRate() {
    if (_totalConflicts == 0) return 0.0;
    return (_resolvedConflicts / _totalConflicts) * 100;
  }

  /// Get total sync attempts
  int getTotalSyncAttempts() => _totalSyncAttempts;

  /// Get successful syncs
  int getSuccessfulSyncs() => _successfulSyncs;

  /// Get failed syncs
  int getFailedSyncs() => _failedSyncs;

  /// Get total conflicts
  int getTotalConflicts() => _totalConflicts;

  /// Get resolved conflicts
  int getResolvedConflicts() => _resolvedConflicts;

  /// Get recent sync events
  List<SyncAnalyticsEvent> getRecentSyncEvents({int limit = 50}) {
    final events = List<SyncAnalyticsEvent>.from(_syncEvents);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }

  /// Get recent auth events
  List<AuthAnalyticsEvent> getRecentAuthEvents({int limit = 50}) {
    final events = List<AuthAnalyticsEvent>.from(_authEvents);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }

  /// Get recent conflict events
  List<ConflictAnalyticsEvent> getRecentConflictEvents({int limit = 50}) {
    final events = List<ConflictAnalyticsEvent>.from(_conflictEvents);
    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return events.take(limit).toList();
  }

  /// Get recent storage snapshots
  List<StorageAnalytics> getRecentStorageSnapshots({int limit = 50}) {
    final snapshots = List<StorageAnalytics>.from(_storageSnapshots);
    snapshots.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return snapshots.take(limit).toList();
  }

  /// Get analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    return {
      'sync': {
        'totalAttempts': _totalSyncAttempts,
        'successful': _successfulSyncs,
        'failed': _failedSyncs,
        'successRate': getSyncSuccessRate(),
        'averageLatencyMs': getAverageSyncLatency(),
      },
      'auth': {
        'totalAttempts': _totalAuthAttempts,
        'failed': _failedAuthAttempts,
        'failureRate': getAuthFailureRate(),
      },
      'conflicts': {
        'total': _totalConflicts,
        'resolved': _resolvedConflicts,
        'resolutionRate': getConflictResolutionRate(),
      },
      'storage':
          _storageSnapshots.isNotEmpty ? _storageSnapshots.last.toJson() : null,
    };
  }

  /// Persist metrics to local storage
  Future<void> _persistMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('analytics_total_sync_attempts', _totalSyncAttempts);
      await prefs.setInt('analytics_successful_syncs', _successfulSyncs);
      await prefs.setInt('analytics_failed_syncs', _failedSyncs);
      await prefs.setInt('analytics_total_auth_attempts', _totalAuthAttempts);
      await prefs.setInt('analytics_failed_auth_attempts', _failedAuthAttempts);
      await prefs.setInt('analytics_total_conflicts', _totalConflicts);
      await prefs.setInt('analytics_resolved_conflicts', _resolvedConflicts);
    } catch (e) {
      safePrint('Error persisting analytics metrics: $e');
    }
  }

  /// Load metrics from local storage
  Future<void> loadMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSyncAttempts = prefs.getInt('analytics_total_sync_attempts') ?? 0;
      _successfulSyncs = prefs.getInt('analytics_successful_syncs') ?? 0;
      _failedSyncs = prefs.getInt('analytics_failed_syncs') ?? 0;
      _totalAuthAttempts = prefs.getInt('analytics_total_auth_attempts') ?? 0;
      _failedAuthAttempts = prefs.getInt('analytics_failed_auth_attempts') ?? 0;
      _totalConflicts = prefs.getInt('analytics_total_conflicts') ?? 0;
      _resolvedConflicts = prefs.getInt('analytics_resolved_conflicts') ?? 0;

      safePrint('Analytics: Metrics loaded from storage');
    } catch (e) {
      safePrint('Error loading analytics metrics: $e');
    }
  }

  /// Reset all analytics data
  Future<void> resetAnalytics() async {
    _syncEvents.clear();
    _authEvents.clear();
    _conflictEvents.clear();
    _storageSnapshots.clear();
    _syncLatencies.clear();

    _totalSyncAttempts = 0;
    _successfulSyncs = 0;
    _failedSyncs = 0;
    _totalAuthAttempts = 0;
    _failedAuthAttempts = 0;
    _totalConflicts = 0;
    _resolvedConflicts = 0;

    await _persistMetrics();

    safePrint('Analytics: All data reset');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _syncEventController.close();
    await _authEventController.close();
    await _conflictEventController.close();
  }
}
