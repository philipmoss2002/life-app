import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import '../services/analytics_service.dart';
import '../services/database_service.dart';

import 'package:uuid/uuid.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
/// Service for tracking sync identifier usage and analytics
/// Integrates with existing services to provide comprehensive analytics
class SyncIdentifierAnalyticsService {
  static final SyncIdentifierAnalyticsService _instance =
      SyncIdentifierAnalyticsService._internal();
  factory SyncIdentifierAnalyticsService() => _instance;
  SyncIdentifierAnalyticsService._internal();

  // Dependencies
  final AnalyticsService _analyticsService = AnalyticsService();
  final DatabaseService _databaseService = DatabaseService.instance;

  bool _isInitialized = false;

  /// Initialize the service and start monitoring
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Take initial sync identifier metrics snapshot
      await _takeSyncIdMetricsSnapshot();

      _isInitialized = true;
      safePrint('SyncIdentifierAnalyticsService: Initialized successfully');
    } catch (e) {
      safePrint('Error initializing SyncIdentifierAnalyticsService: $e');
    }
  }

  /// Track document creation with sync identifier analysis
  Future<void> trackDocumentCreation(Document document) async {
    try {
      final hasSyncId = document.syncId != null && document.syncId!.isNotEmpty;

      await _analyticsService.trackDocumentCreated(
        documentId: document.syncId,
        syncId: document.syncId,
        hasSyncId: hasSyncId,
      );

      safePrint(
          'SyncIdentifierAnalytics: Document creation tracked - syncId: ${document.syncId}, hasSyncId: $hasSyncId');
    } catch (e) {
      safePrint('Error tracking document creation: $e');
    }
  }

  /// Track sync operation with sync identifier analysis
  Future<void> trackSyncOperation({
    required AnalyticsSyncEventType type,
    required bool success,
    String? documentId,
    String? syncId,
    int? latencyMs,
    String? errorMessage,
  }) async {
    try {
      await _analyticsService.trackSyncEvent(type: type, success: success, documentId: documentId, syncId: syncId, latencyMs: latencyMs, errorMessage: errorMessage, id: uuid.v4(), eventType: "sync_event", entityType: "document", entityId: "unknown", message: "Sync event", timestamp: amplify_core.TemporalDateTime.now());

      safePrint(
          'SyncIdentifierAnalytics: Sync operation tracked - Type: $type, Success: $success, SyncId: ${syncId ?? 'none'}');
    } catch (e) {
      safePrint('Error tracking sync operation: $e');
    }
  }

  /// Track conflict with sync identifier information
  Future<void> trackConflict({
    required String documentId,
    String? syncId,
    required String conflictType,
  }) async {
    try {
      await _analyticsService.trackConflictDetected(
        documentId: documentId,
        syncId: syncId,
        conflictType: conflictType,
      );

      safePrint(
          'SyncIdentifierAnalytics: Conflict tracked - DocumentId: $documentId, SyncId: ${syncId ?? 'none'}');
    } catch (e) {
      safePrint('Error tracking conflict: $e');
    }
  }

  /// Take a snapshot of current sync identifier metrics
  Future<void> _takeSyncIdMetricsSnapshot() async {
    try {
      // Get all documents from database
      final documents = await _databaseService.getAllDocuments();

      final totalDocuments = documents.length;
      final documentsWithSyncId = documents
          .where((doc) => doc.syncId != null && doc.syncId!.isNotEmpty)
          .length;
      final documentsWithoutSyncId = totalDocuments - documentsWithSyncId;

      await _analyticsService.trackSyncIdentifierMetrics(
        totalDocuments: totalDocuments,
        documentsWithSyncId: documentsWithSyncId,
        documentsWithoutSyncId: documentsWithoutSyncId,
      );

      safePrint(
          'SyncIdentifierAnalytics: Metrics snapshot taken - Total: $totalDocuments, With SyncId: $documentsWithSyncId');
    } catch (e) {
      safePrint('Error taking sync ID metrics snapshot: $e');
    }
  }

  /// Take sync identifier metrics snapshot (public method)
  Future<void> takeSyncIdMetricsSnapshot() async {
    await _takeSyncIdMetricsSnapshot();
  }

  /// Get sync identifier coverage report
  Future<Map<String, dynamic>> getSyncIdCoverageReport() async {
    try {
      final documents = await _databaseService.getAllDocuments();
      final totalDocuments = documents.length;

      if (totalDocuments == 0) {
        return {
          'totalDocuments': 0,
          'documentsWithSyncId': 0,
          'documentsWithoutSyncId': 0,
          'coveragePercentage': 0.0,
          'allHaveSyncIds': true,
          'documentsNeedingSyncIds': [],
        };
      }

      final documentsWithSyncId = documents
          .where((doc) => doc.syncId != null && doc.syncId!.isNotEmpty)
          .toList();
      final documentsWithoutSyncId = documents
          .where((doc) => doc.syncId == null || doc.syncId!.isEmpty)
          .toList();

      final coveragePercentage =
          (documentsWithSyncId.length / totalDocuments) * 100;
      final allHaveSyncIds = documentsWithoutSyncId.isEmpty;

      return {
        'totalDocuments': totalDocuments,
        'documentsWithSyncId': documentsWithSyncId.length,
        'documentsWithoutSyncId': documentsWithoutSyncId.length,
        'coveragePercentage': coveragePercentage,
        'allHaveSyncIds': allHaveSyncIds,
        'documentsNeedingSyncIds': documentsWithoutSyncId
            .map((doc) => {
                  'syncId': doc.syncId,
                  'title': doc.title,
                  'createdAt': doc.createdAt.format(),
                })
            .toList(),
      };
    } catch (e) {
      safePrint('Error generating sync ID coverage report: $e');
      return {
        'error': e.toString(),
        'totalDocuments': 0,
        'documentsWithSyncId': 0,
        'documentsWithoutSyncId': 0,
        'coveragePercentage': 0.0,
        'allHaveSyncIds': false,
        'documentsNeedingSyncIds': [],
      };
    }
  }

  /// Get sync operation analytics summary
  Map<String, dynamic> getSyncOperationSummary() {
    try {
      final summary = _analyticsService.getAnalyticsSummary();

      return {
        'syncOperations': summary['sync'],
        'syncIdentifierUsage': summary['syncIdentifiers'],
      };
    } catch (e) {
      safePrint('Error getting sync operation summary: $e');
      return {
        'error': e.toString(),
        'syncOperations': {},
        'syncIdentifierUsage': {},
      };
    }
  }

  /// Get detailed analytics report
  Future<Map<String, dynamic>> getDetailedAnalyticsReport() async {
    try {
      final coverageReport = await getSyncIdCoverageReport();
      final operationSummary = getSyncOperationSummary();

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'syncIdentifierCoverage': coverageReport,
        'syncOperations': operationSummary,
        'recommendations': _generateRecommendations(coverageReport),
      };
    } catch (e) {
      safePrint('Error generating detailed analytics report: $e');
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Generate recommendations based on analytics data
  List<String> _generateRecommendations(Map<String, dynamic> coverageReport) {
    final recommendations = <String>[];

    try {
      final coveragePercentage = coverageReport['coveragePercentage'] as double;
      final documentsWithoutSyncId =
          coverageReport['documentsWithoutSyncId'] as int;
      final allHaveSyncIds = coverageReport['allHaveSyncIds'] as bool;

      if (!allHaveSyncIds) {
        if (coveragePercentage < 50) {
          recommendations.add(
              'Low sync identifier coverage ($coveragePercentage%). New documents will automatically get sync identifiers.');
        } else if (coveragePercentage < 90) {
          recommendations.add(
              'Moderate sync identifier coverage ($coveragePercentage%). $documentsWithoutSyncId documents still need sync identifiers.');
        } else {
          recommendations.add(
              'High sync identifier coverage ($coveragePercentage%). Only $documentsWithoutSyncId documents remaining.');
        }
      } else {
        recommendations.add(
            '✅ All documents have sync identifiers. Sync system is fully operational.');
      }

      final syncIdUsageRate = _analyticsService.getSyncIdOperationUsageRate();
      if (syncIdUsageRate < 80 && !allHaveSyncIds) {
        recommendations.add(
            'Sync operations using sync identifiers: $syncIdUsageRate%. Documents without sync identifiers will get them automatically.');
      }
    } catch (e) {
      recommendations.add('Error generating recommendations: $e');
    }

    return recommendations;
  }

  /// Schedule periodic metrics snapshots
  Timer? _metricsTimer;

  /// Start periodic metrics collection
  void startPeriodicMetricsCollection(
      {Duration interval = const Duration(minutes: 5)}) {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(interval, (_) async {
      await _takeSyncIdMetricsSnapshot();
    });

    safePrint(
        'SyncIdentifierAnalytics: Started periodic metrics collection (${interval.inMinutes} min intervals)');
  }

  /// Stop periodic metrics collection
  void stopPeriodicMetricsCollection() {
    _metricsTimer?.cancel();
    _metricsTimer = null;
    safePrint('SyncIdentifierAnalytics: Stopped periodic metrics collection');
  }

  /// Dispose resources
  Future<void> dispose() async {
    _metricsTimer?.cancel();
    _isInitialized = false;
    safePrint('SyncIdentifierAnalyticsService: Disposed');
  }
}
