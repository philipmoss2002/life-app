import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/analytics_service.dart';
import 'package:household_docs_app/services/sync_identifier_analytics_service.dart';

void main() {
  group('Sync Identifier Analytics', () {
    late AnalyticsService analyticsService;
    late SyncIdentifierAnalyticsService syncIdAnalyticsService;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      analyticsService = AnalyticsService();
      syncIdAnalyticsService = SyncIdentifierAnalyticsService();
    });

    tearDown(() async {
      await analyticsService.resetAnalytics();
      await syncIdAnalyticsService.dispose();
    });

    test('should track sync events with sync identifiers', () async {
      // Track sync event with sync identifier
      await analyticsService.trackSyncEvent(
        documentId: 'doc-123',
        latencyMs: 150,
      );

      // Track sync event without sync identifier
      await analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpload,
        success: true,
        documentId: 'doc-456',
        latencyMs: 200,
      );

      // Verify metrics
      expect(analyticsService.getSyncOperationsWithId(), equals(1));
      expect(analyticsService.getSyncOperationsWithoutId(), equals(1));
      expect(analyticsService.getSyncIdOperationUsageRate(), equals(50.0));

      // Verify events contain sync identifier information
      final recentEvents = analyticsService.getRecentSyncEvents(limit: 10);
      expect(recentEvents.length, equals(2));

      final eventWithSyncId = recentEvents.firstWhere((e) => e.syncId != null);
      expect(eventWithSyncId.syncId, equals('test-sync-id-123'));
      expect(eventWithSyncId.hasSyncId, equals(true));

      final eventWithoutSyncId =
          recentEvents.firstWhere((e) => e.syncId == null);
      expect(eventWithoutSyncId.hasSyncId, equals(false));
    });

    test('should track document creation with sync identifier status',
        () async {
      // Track document creation with sync identifier
      await analyticsService.trackDocumentCreated(
        documentId: 'doc-123',
        syncId: 'sync-id-123',
        hasSyncId: true,
      );

      // Track document creation without sync identifier
      await analyticsService.trackDocumentCreated(
        documentId: 'doc-456',
        hasSyncId: false,
      );

      // Verify metrics
      expect(analyticsService.getDocumentsCreatedWithSyncId(), equals(1));
      expect(analyticsService.getDocumentsCreatedWithoutSyncId(), equals(1));
      expect(analyticsService.getSyncIdDocumentCreationRate(), equals(50.0));
    });

    test('should track migration progress', () async {
      // Track migration progress
      await analyticsService.trackMigrationProgress(
        phase: 'Local migration',
        totalDocuments: 100,
        migratedDocuments: 75,
        failedDocuments: 5,
        status: 'in_progress',
        errors: ['Error migrating doc-123'],
      );

      // Verify migration snapshots
      final migrationSnapshots =
          analyticsService.getRecentMigrationSnapshots(limit: 10);
      expect(migrationSnapshots.length, equals(1));

      final snapshot = migrationSnapshots.first;
      expect(snapshot.phase, equals('Local migration'));
      expect(snapshot.totalDocuments, equals(100));
      expect(snapshot.migratedDocuments, equals(75));
      expect(snapshot.failedDocuments, equals(5));
      expect(snapshot.progressPercentage, equals(80.0)); // (75 + 5) / 100 * 100
      expect(snapshot.status, equals('in_progress'));
      expect(snapshot.errors, contains('Error migrating doc-123'));
    });

    test('should track sync identifier metrics', () async {
      // Track sync identifier metrics
      await analyticsService.trackSyncIdentifierMetrics(
        totalDocuments: 200,
        documentsWithSyncId: 150,
        documentsWithoutSyncId: 50,
      );

      // Verify sync identifier metrics
      final syncIdMetrics = analyticsService.getRecentSyncIdMetrics(limit: 10);
      expect(syncIdMetrics.length, equals(1));

      final metrics = syncIdMetrics.first;
      expect(metrics.totalDocuments, equals(200));
      expect(metrics.documentsWithSyncId, equals(150));
      expect(metrics.documentsWithoutSyncId, equals(50));
      expect(metrics.syncIdCoverage, equals(75.0)); // 150 / 200 * 100
    });

    test('should track conflicts with sync identifiers', () async {
      // Track conflict with sync identifier
      await analyticsService.trackConflictDetected(
        documentId: 'doc-123',
        syncId: 'sync-id-123',
        conflictType: 'version_conflict',
      );

      // Track conflict without sync identifier
      await analyticsService.trackConflictDetected(
        documentId: 'doc-456',
        conflictType: 'content_conflict',
      );

      // Verify conflict events
      final conflictEvents =
          analyticsService.getRecentConflictEvents(limit: 10);
      expect(conflictEvents.length, equals(2));

      final conflictWithSyncId =
          conflictEvents.firstWhere((e) => e.syncId != null);
      expect(conflictWithSyncId.syncId, equals('sync-id-123'));
      expect(conflictWithSyncId.conflictType, equals('version_conflict'));

      final conflictWithoutSyncId =
          conflictEvents.firstWhere((e) => e.syncId == null);
      expect(conflictWithoutSyncId.conflictType, equals('content_conflict'));
    });

    test('should include sync identifier data in analytics summary', () async {
      // Add some test data
      await analyticsService.trackSyncEvent(
      );

      await analyticsService.trackDocumentCreated(
        documentId: 'doc-123',
        syncId: 'sync-id-123',
        hasSyncId: true,
      );

      await analyticsService.trackSyncIdentifierMetrics(
        totalDocuments: 100,
        documentsWithSyncId: 80,
        documentsWithoutSyncId: 20,
      );

      // Get analytics summary
      final summary = analyticsService.getAnalyticsSummary();

      // Verify sync identifier data is included
      expect(summary['sync']['operationsWithSyncId'], equals(1));
      expect(summary['sync']['operationsWithoutSyncId'], equals(0));
      expect(summary['sync']['syncIdUsageRate'], equals(100.0));

      expect(
          summary['syncIdentifiers']['documentsCreatedWithSyncId'], equals(1));
      expect(summary['syncIdentifiers']['documentsCreatedWithoutSyncId'],
          equals(0));
      expect(summary['syncIdentifiers']['documentCreationRate'], equals(100.0));

      expect(summary['syncIdentifiers']['latestMetrics'], isNotNull);
      expect(summary['syncIdentifiers']['latestMetrics']['syncIdCoverage'],
          equals(80.0));
    });

    test('should handle empty analytics data gracefully', () {
      // Test with no data
      expect(analyticsService.getSyncIdOperationUsageRate(), equals(0.0));
      expect(analyticsService.getSyncIdDocumentCreationRate(), equals(0.0));
      expect(analyticsService.getLatestSyncIdMetrics(), isNull);
      expect(analyticsService.getLatestMigrationStatus(), isNull);

      final summary = analyticsService.getAnalyticsSummary();
      expect(summary['syncIdentifiers']['latestMetrics'], isNull);
      expect(summary['migration'], isNull);
    });
  });
}
