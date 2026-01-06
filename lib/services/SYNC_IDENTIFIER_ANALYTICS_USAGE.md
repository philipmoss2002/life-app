# Sync Identifier Analytics Usage Guide

This document explains how to use the enhanced analytics system for tracking sync identifier usage and migration progress.

## Overview

The analytics system has been enhanced to track:
1. **Sync Identifier Usage**: Track which sync operations use sync identifiers vs legacy document IDs
2. **Migration Progress**: Monitor the progress of migrating documents to use sync identifiers
3. **Document Creation**: Track whether new documents are created with sync identifiers
4. **Conflict Resolution**: Track conflicts with sync identifier information

## Services

### AnalyticsService (Enhanced)

The main analytics service now includes sync identifier tracking:

```dart
final analyticsService = AnalyticsService();

// Track sync events with sync identifier information
await analyticsService.trackSyncEvent(
  type: AnalyticsSyncEventType.documentUpload,
  success: true,
  documentId: document.id.toString(),
  syncId: document.syncId, // Now includes sync identifier
  latencyMs: 150,
);

// Track document creation with sync identifier status
await analyticsService.trackDocumentCreated(
  documentId: document.id.toString(),
  syncId: document.syncId,
  hasSyncId: document.syncId != null && document.syncId!.isNotEmpty,
);

// Track migration progress
await analyticsService.trackMigrationProgress(
  phase: 'Local migration',
  totalDocuments: 100,
  migratedDocuments: 75,
  failedDocuments: 5,
  status: 'in_progress',
  errors: ['Error migrating doc-123'],
);

// Track sync identifier metrics
await analyticsService.trackSyncIdentifierMetrics(
  totalDocuments: 200,
  documentsWithSyncId: 150,
  documentsWithoutSyncId: 50,
);

// Track conflicts with sync identifier information
await analyticsService.trackConflictDetected(
  documentId: document.id.toString(),
  syncId: document.syncId,
  conflictType: 'version_conflict',
);
```

### SyncIdentifierAnalyticsService (New)

A specialized service for sync identifier analytics:

```dart
final syncIdAnalytics = SyncIdentifierAnalyticsService();

// Initialize the service
await syncIdAnalytics.initialize();

// Track document creation
await syncIdAnalytics.trackDocumentCreation(document);

// Track sync operations
await syncIdAnalytics.trackSyncOperation(
  type: AnalyticsSyncEventType.documentUpload,
  success: true,
  documentId: document.id.toString(),
  syncId: document.syncId,
);

// Get coverage report
final coverageReport = await syncIdAnalytics.getSyncIdCoverageReport();
print('Sync ID Coverage: ${coverageReport['coveragePercentage']}%');

// Get detailed analytics report
final detailedReport = await syncIdAnalytics.getDetailedAnalyticsReport();

// Start periodic metrics collection
syncIdAnalytics.startPeriodicMetricsCollection(
  interval: Duration(minutes: 5),
);
```

## Metrics Available

### Sync Identifier Usage Metrics

```dart
// Get sync operation usage rates
final operationUsageRate = analyticsService.getSyncIdOperationUsageRate();
final documentCreationRate = analyticsService.getSyncIdDocumentCreationRate();

// Get counts
final operationsWithId = analyticsService.getSyncOperationsWithId();
final operationsWithoutId = analyticsService.getSyncOperationsWithoutId();
final documentsCreatedWithId = analyticsService.getDocumentsCreatedWithSyncId();
final documentsCreatedWithoutId = analyticsService.getDocumentsCreatedWithoutSyncId();
```

### Migration Progress Metrics

```dart
// Get recent migration snapshots
final migrationSnapshots = analyticsService.getRecentMigrationSnapshots();
final latestMigration = analyticsService.getLatestMigrationStatus();

// Get sync identifier metrics
final syncIdMetrics = analyticsService.getRecentSyncIdMetrics();
final latestMetrics = analyticsService.getLatestSyncIdMetrics();
```

### Analytics Summary

```dart
final summary = analyticsService.getAnalyticsSummary();

// Access sync identifier data
final syncData = summary['sync'];
print('Sync ID Usage Rate: ${syncData['syncIdUsageRate']}%');

final syncIdData = summary['syncIdentifiers'];
print('Document Creation Rate: ${syncIdData['documentCreationRate']}%');

final migrationData = summary['migration'];
if (migrationData != null) {
  print('Migration Status: ${migrationData['status']}');
}
```

## Integration Examples

### In Cloud Sync Service

```dart
// When uploading a document
await _analyticsService.trackSyncEvent(
  type: AnalyticsSyncEventType.documentUpload,
  success: true,
  latencyMs: latency,
  documentId: document.id.toString(),
  syncId: document.syncId, // Include sync identifier
);
```

### In Conflict Resolution Service

```dart
// When detecting a conflict
await _analyticsService.trackConflictDetected(
  documentId: conflict.documentId,
  syncId: conflict.syncId,
  conflictType: 'version_mismatch',
);

// When resolving a conflict
await _analyticsService.trackConflictResolved(
  conflictId: conflictId,
  resolutionStrategy: strategy.name,
);
```

### In Document Creation

```dart
// When creating a new document
final document = Document(...);
await _databaseService.createDocument(document);

// Track the creation
await _syncIdAnalytics.trackDocumentCreation(document);
```

## Monitoring Migration Progress

```dart
// Subscribe to migration progress
final migrationManager = MigrationManager();
migrationManager.progressStream.listen((progress) {
  print('Migration Progress: ${progress.progressPercentage}%');
  print('Phase: ${progress.currentPhase}');
  print('Status: ${progress.status}');
});

// Get coverage report
final syncIdAnalytics = SyncIdentifierAnalyticsService();
final report = await syncIdAnalytics.getSyncIdCoverageReport();

if (report['migrationComplete']) {
  print('✅ Migration complete!');
} else {
  print('📊 Migration progress: ${report['coveragePercentage']}%');
  print('Documents needing migration: ${report['documentsWithoutSyncId']}');
}
```

## Recommendations System

The analytics service provides automatic recommendations:

```dart
final detailedReport = await syncIdAnalytics.getDetailedAnalyticsReport();
final recommendations = detailedReport['recommendations'] as List<String>;

for (final recommendation in recommendations) {
  print('💡 $recommendation');
}
```

Example recommendations:
- "Low sync identifier coverage (45%). Consider running migration to improve sync reliability."
- "✅ All documents have sync identifiers. Migration is complete."
- "Migration failed with 3 failures. Review error logs and retry migration."

## Best Practices

1. **Initialize Early**: Initialize `SyncIdentifierAnalyticsService` early in your app lifecycle
2. **Track All Operations**: Ensure all sync operations include sync identifier information
3. **Monitor Migration**: Use the migration progress tracking to monitor large migrations
4. **Periodic Snapshots**: Use periodic metrics collection to track trends over time
5. **Review Recommendations**: Regularly check the recommendations for optimization opportunities

## Streams and Real-time Updates

```dart
// Listen to migration progress
syncIdAnalytics.migrationStream.listen((progress) {
  // Update UI with migration progress
});

// Listen to sync identifier metrics
analyticsService.syncIdMetricsStream.listen((metrics) {
  // Update dashboard with latest metrics
});

// Listen to sync events
analyticsService.syncEventStream.listen((event) {
  if (event.hasSyncId == false) {
    // Alert: sync operation without sync identifier
  }
});
```

This enhanced analytics system provides comprehensive visibility into sync identifier adoption and migration progress, helping ensure a smooth transition to the new sync identifier system.