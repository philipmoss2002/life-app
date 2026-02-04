import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Model representing a sync analytics event
class SyncAnalyticsEvent {
  final String id;
  final DateTime timestamp;
  final AnalyticsSyncEventType type;
  final bool success;
  final int? latencyMs;
  final String? errorMessage;
  final String? documentId;
  final String? syncId;
  final bool? hasSyncId;

  SyncAnalyticsEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.success,
    this.latencyMs,
    this.errorMessage,
    this.documentId,
    this.syncId,
    this.hasSyncId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'type': type.toString(),
        'success': success,
        'latencyMs': latencyMs,
        'errorMessage': errorMessage,
        'documentId': documentId,
        'syncId': syncId,
        'hasSyncId': hasSyncId,
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
  final String? syncId;
  final String conflictType;
  final String? resolutionStrategy;
  final DateTime? resolvedAt;

  ConflictAnalyticsEvent({
    required this.id,
    required this.timestamp,
    required this.documentId,
    this.syncId,
    required this.conflictType,
    this.resolutionStrategy,
    this.resolvedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'documentId': documentId,
        'syncId': syncId,
        'conflictType': conflictType,
        'resolutionStrategy': resolutionStrategy,
        'resolvedAt': resolvedAt?.toIso8601String(),
      };
}

/// Model representing sync identifier metrics
class SyncIdentifierMetrics {
  final DateTime timestamp;
  final int totalDocuments;
  final int documentsWithSyncId;
  final int documentsWithoutSyncId;
  final double syncIdCoverage;
  final int syncOperationsWithId;
  final int syncOperationsWithoutId;

  SyncIdentifierMetrics({
    required this.timestamp,
    required this.totalDocuments,
    required this.documentsWithSyncId,
    required this.documentsWithoutSyncId,
    required this.syncIdCoverage,
    required this.syncOperationsWithId,
    required this.syncOperationsWithoutId,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'totalDocuments': totalDocuments,
        'documentsWithSyncId': documentsWithSyncId,
        'documentsWithoutSyncId': documentsWithoutSyncId,
        'syncIdCoverage': syncIdCoverage,
        'syncOperationsWithId': syncOperationsWithId,
        'syncOperationsWithoutId': syncOperationsWithoutId,
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
  accountDeleted,
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
  final List<SyncIdentifierMetrics> _syncIdMetrics = [];

  // Metrics
  int _totalSyncAttempts = 0;
  int _successfulSyncs = 0;
  int _failedSyncs = 0;
  final List<int> _syncLatencies = [];
  int _totalAuthAttempts = 0;
  int _failedAuthAttempts = 0;
  int _totalConflicts = 0;
  int _resolvedConflicts = 0;

  // Sync identifier metrics
  int _syncOperationsWithId = 0;
  int _syncOperationsWithoutId = 0;
  int _documentsCreatedWithSyncId = 0;
  int _documentsCreatedWithoutSyncId = 0;

  // Event streaming
  final StreamController<SyncAnalyticsEvent> _syncEventController =
      StreamController<SyncAnalyticsEvent>.broadcast();
  final StreamController<AuthAnalyticsEvent> _authEventController =
      StreamController<AuthAnalyticsEvent>.broadcast();
  final StreamController<ConflictAnalyticsEvent> _conflictEventController =
      StreamController<ConflictAnalyticsEvent>.broadcast();
  final StreamController<SyncIdentifierMetrics> _syncIdMetricsController =
      StreamController<SyncIdentifierMetrics>.broadcast();

  /// Stream of sync analytics events
  Stream<SyncAnalyticsEvent> get syncEventStream => _syncEventController.stream;

  /// Stream of auth analytics events
  Stream<AuthAnalyticsEvent> get authEventStream => _authEventController.stream;

  /// Stream of conflict analytics events
  Stream<ConflictAnalyticsEvent> get conflictEventStream =>
      _conflictEventController.stream;

  /// Stream of sync identifier metrics
  Stream<SyncIdentifierMetrics> get syncIdMetricsStream =>
      _syncIdMetricsController.stream;

  /// Track a sync event
  Future<void> trackSyncEvent({
    required AnalyticsSyncEventType type,
    required bool success,
    int? latencyMs,
    String? errorMessage,
    String? documentId,
    String? syncId,
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

    // Track sync identifier usage
    final hasSyncId = syncId != null && syncId.isNotEmpty;
    if (hasSyncId) {
      _syncOperationsWithId++;
    } else {
      _syncOperationsWithoutId++;
    }

    final event = SyncAnalyticsEvent(
      id: const Uuid().v4(),
      timestamp: DateTime.now(),
      type: type,
      success: success,
      latencyMs: latencyMs,
      errorMessage: errorMessage,
      documentId: documentId,
      syncId: syncId,
      hasSyncId: hasSyncId,
    );

    _syncEvents.add(event);
    _syncEventController.add(event);

    // Persist metrics
    await _persistMetrics();

    safePrint(
        'Analytics: Sync event tracked - ${type.toString()}, success: $success, syncId: ${syncId ?? 'none'}');
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
      id: const Uuid().v4(),
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
    String? syncId,
    required String conflictType,
  }) async {
    _totalConflicts++;

    final event = ConflictAnalyticsEvent(
      id: 'conflict_${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      documentId: documentId,
      syncId: syncId,
      conflictType: conflictType,
    );

    _conflictEvents.add(event);
    _conflictEventController.add(event);

    // Persist metrics
    await _persistMetrics();

    safePrint(
        'Analytics: Conflict detected for document $documentId (syncId: ${syncId ?? 'none'})');
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

  /// Track document creation with sync identifier status
  Future<void> trackDocumentCreated({
    required String documentId,
    String? syncId,
    required bool hasSyncId,
  }) async {
    if (hasSyncId) {
      _documentsCreatedWithSyncId++;
    } else {
      _documentsCreatedWithoutSyncId++;
    }

    await _persistMetrics();

    safePrint(
        'Analytics: Document created - ID: $documentId, syncId: ${syncId ?? 'none'}, hasSyncId: $hasSyncId');
  }

  /// Track sync identifier metrics snapshot
  Future<void> trackSyncIdentifierMetrics({
    required int totalDocuments,
    required int documentsWithSyncId,
    required int documentsWithoutSyncId,
  }) async {
    final syncIdCoverage =
        totalDocuments > 0 ? (documentsWithSyncId / totalDocuments) * 100 : 0.0;

    final metrics = SyncIdentifierMetrics(
      timestamp: DateTime.now(),
      totalDocuments: totalDocuments,
      documentsWithSyncId: documentsWithSyncId,
      documentsWithoutSyncId: documentsWithoutSyncId,
      syncIdCoverage: syncIdCoverage,
      syncOperationsWithId: _syncOperationsWithId,
      syncOperationsWithoutId: _syncOperationsWithoutId,
    );

    _syncIdMetrics.add(metrics);
    _syncIdMetricsController.add(metrics);

    // Keep only last 100 snapshots
    if (_syncIdMetrics.length > 100) {
      _syncIdMetrics.removeAt(0);
    }

    safePrint(
        'Analytics: Sync ID metrics - Coverage: ${syncIdCoverage.toStringAsFixed(2)}%, Operations with ID: $_syncOperationsWithId');
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

  /// Get sync operations with sync identifiers
  int getSyncOperationsWithId() => _syncOperationsWithId;

  /// Get sync operations without sync identifiers
  int getSyncOperationsWithoutId() => _syncOperationsWithoutId;

  /// Get documents created with sync identifiers
  int getDocumentsCreatedWithSyncId() => _documentsCreatedWithSyncId;

  /// Get documents created without sync identifiers
  int getDocumentsCreatedWithoutSyncId() => _documentsCreatedWithoutSyncId;

  /// Get sync identifier usage rate for operations
  double getSyncIdOperationUsageRate() {
    final totalOperations = _syncOperationsWithId + _syncOperationsWithoutId;
    if (totalOperations == 0) return 0.0;
    return (_syncOperationsWithId / totalOperations) * 100;
  }

  /// Get sync identifier usage rate for document creation
  double getSyncIdDocumentCreationRate() {
    final totalCreated =
        _documentsCreatedWithSyncId + _documentsCreatedWithoutSyncId;
    if (totalCreated == 0) return 0.0;
    return (_documentsCreatedWithSyncId / totalCreated) * 100;
  }

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

  /// Get recent sync identifier metrics
  List<SyncIdentifierMetrics> getRecentSyncIdMetrics({int limit = 50}) {
    final metrics = List<SyncIdentifierMetrics>.from(_syncIdMetrics);
    metrics.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return metrics.take(limit).toList();
  }

  /// Get latest sync identifier metrics
  SyncIdentifierMetrics? getLatestSyncIdMetrics() {
    if (_syncIdMetrics.isEmpty) return null;
    return _syncIdMetrics.last;
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
        'operationsWithSyncId': _syncOperationsWithId,
        'operationsWithoutSyncId': _syncOperationsWithoutId,
        'syncIdUsageRate': getSyncIdOperationUsageRate(),
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
      'syncIdentifiers': {
        'documentsCreatedWithSyncId': _documentsCreatedWithSyncId,
        'documentsCreatedWithoutSyncId': _documentsCreatedWithoutSyncId,
        'documentCreationRate': getSyncIdDocumentCreationRate(),
        'latestMetrics':
            _syncIdMetrics.isNotEmpty ? _syncIdMetrics.last.toJson() : null,
      },
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
      await prefs.setInt(
          'analytics_sync_operations_with_id', _syncOperationsWithId);
      await prefs.setInt(
          'analytics_sync_operations_without_id', _syncOperationsWithoutId);
      await prefs.setInt('analytics_documents_created_with_sync_id',
          _documentsCreatedWithSyncId);
      await prefs.setInt('analytics_documents_created_without_sync_id',
          _documentsCreatedWithoutSyncId);
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
      _syncOperationsWithId =
          prefs.getInt('analytics_sync_operations_with_id') ?? 0;
      _syncOperationsWithoutId =
          prefs.getInt('analytics_sync_operations_without_id') ?? 0;
      _documentsCreatedWithSyncId =
          prefs.getInt('analytics_documents_created_with_sync_id') ?? 0;
      _documentsCreatedWithoutSyncId =
          prefs.getInt('analytics_documents_created_without_sync_id') ?? 0;

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
    _syncIdMetrics.clear();
    _syncLatencies.clear();

    _totalSyncAttempts = 0;
    _successfulSyncs = 0;
    _failedSyncs = 0;
    _totalAuthAttempts = 0;
    _failedAuthAttempts = 0;
    _totalConflicts = 0;
    _resolvedConflicts = 0;
    _syncOperationsWithId = 0;
    _syncOperationsWithoutId = 0;
    _documentsCreatedWithSyncId = 0;
    _documentsCreatedWithoutSyncId = 0;

    await _persistMetrics();

    safePrint('Analytics: All data reset');
  }

  /// Clear analytics data for user isolation
  /// Called when user signs out to prevent data leakage between users
  Future<void> clearUserAnalytics() async {
    try {
      // Clear in-memory data
      _syncEvents.clear();
      _authEvents.clear();
      _conflictEvents.clear();
      _storageSnapshots.clear();
      _syncIdMetrics.clear();
      _syncLatencies.clear();

      _totalSyncAttempts = 0;
      _successfulSyncs = 0;
      _failedSyncs = 0;
      _totalAuthAttempts = 0;
      _failedAuthAttempts = 0;
      _totalConflicts = 0;
      _resolvedConflicts = 0;
      _syncOperationsWithId = 0;
      _syncOperationsWithoutId = 0;
      _documentsCreatedWithSyncId = 0;
      _documentsCreatedWithoutSyncId = 0;

      // Clear persisted metrics from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('analytics_total_sync_attempts');
      await prefs.remove('analytics_successful_syncs');
      await prefs.remove('analytics_failed_syncs');
      await prefs.remove('analytics_total_auth_attempts');
      await prefs.remove('analytics_failed_auth_attempts');
      await prefs.remove('analytics_total_conflicts');
      await prefs.remove('analytics_resolved_conflicts');
      await prefs.remove('analytics_sync_operations_with_id');
      await prefs.remove('analytics_sync_operations_without_id');
      await prefs.remove('analytics_documents_created_with_sync_id');
      await prefs.remove('analytics_documents_created_without_sync_id');

      safePrint('Analytics: User-specific data cleared for user isolation');
    } catch (e) {
      safePrint('Error clearing user analytics: $e');
    }
  }

  /// Reset analytics for new user session
  /// Called when a new user signs in to ensure clean state
  Future<void> resetForNewUser() async {
    await clearUserAnalytics();
    safePrint('Analytics: Reset for new user session');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _syncEventController.close();
    await _authEventController.close();
    await _conflictEventController.close();
    await _syncIdMetricsController.close();
  }
}
