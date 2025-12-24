# Sync Identifier Refactor - Monitoring and Alerting Configuration

## Overview

This document defines the monitoring and alerting configuration for the sync identifier refactor deployment. It includes metrics collection, dashboard configuration, and alert rules to ensure system health and data integrity.

## Key Performance Indicators (KPIs)

### Migration Health Metrics

1. **Sync Identifier Coverage**
   - Metric: `sync_identifier_coverage_percentage`
   - Target: 100%
   - Description: Percentage of documents with valid sync identifiers

2. **Migration Success Rate**
   - Metric: `migration_success_rate`
   - Target: >99%
   - Description: Percentage of documents successfully migrated

3. **Migration Duration**
   - Metric: `migration_duration_seconds`
   - Target: <300 seconds for 1000 documents
   - Description: Time taken to complete migration

### Sync Performance Metrics

1. **Sync Operation Success Rate**
   - Metric: `sync_operation_success_rate`
   - Target: >99.5%
   - Description: Percentage of successful sync operations

2. **Sync Operation Latency**
   - Metric: `sync_operation_duration_seconds`
   - Target: <5 seconds (p95)
   - Description: Time taken for sync operations

3. **Conflict Resolution Rate**
   - Metric: `conflict_resolution_rate`
   - Target: <1% of sync operations
   - Description: Percentage of operations requiring conflict resolution

### Data Integrity Metrics

1. **Duplicate Sync Identifiers**
   - Metric: `duplicate_sync_identifiers_count`
   - Target: 0
   - Description: Number of duplicate sync identifiers detected

2. **Invalid Sync Identifiers**
   - Metric: `invalid_sync_identifiers_count`
   - Target: 0
   - Description: Number of invalid sync identifier formats

3. **Orphaned File Attachments**
   - Metric: `orphaned_file_attachments_count`
   - Target: 0
   - Description: File attachments without valid sync identifiers

## Metrics Collection Implementation

### Analytics Service Integration

```dart
// lib/services/sync_identifier_analytics_service.dart
class SyncIdentifierAnalyticsService {
  // Track sync identifier coverage
  Future<void> trackSyncIdentifierCoverage() async {
    final validation = await MigrationManager().validateMigration();
    final coverage = validation.documentsWithSyncId / validation.totalDocuments * 100;
    
    await _analyticsService.recordMetric(
      'sync_identifier_coverage_percentage',
      coverage,
      {
        'total_documents': validation.totalDocuments,
        'documents_with_sync_id': validation.documentsWithSyncId,
        'documents_without_sync_id': validation.documentsWithoutSyncId,
      },
    );
  }

  // Track migration progress
  Future<void> trackMigrationProgress(MigrationManagerProgress progress) async {
    await _analyticsService.recordMetric(
      'migration_progress_percentage',
      progress.progressPercentage * 100,
      {
        'status': progress.status.toString(),
        'total_documents': progress.totalDocuments,
        'migrated_documents': progress.migratedDocuments,
        'failed_documents': progress.failedDocuments,
        'current_phase': progress.currentPhase,
      },
    );
  }

  // Track sync operation performance
  Future<void> trackSyncOperation(
    String syncId,
    SyncOperationType operation,
    bool success,
    Duration duration,
  ) async {
    await _analyticsService.recordMetric(
      'sync_operation_duration_seconds',
      duration.inMilliseconds / 1000.0,
      {
        'operation_type': operation.toString(),
        'success': success,
        'has_sync_id': syncId.isNotEmpty,
      },
    );

    await _analyticsService.recordEvent(
      'sync_operation_completed',
      {
        'sync_id': syncId,
        'operation_type': operation.toString(),
        'success': success,
        'duration_ms': duration.inMilliseconds,
      },
    );
  }
}
```

### Custom Metrics Dashboard

```yaml
# monitoring/dashboards/sync_identifier_dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sync-identifier-dashboard
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "Sync Identifier Refactor Monitoring",
        "panels": [
          {
            "title": "Sync Identifier Coverage",
            "type": "stat",
            "targets": [
              {
                "expr": "sync_identifier_coverage_percentage",
                "legendFormat": "Coverage %"
              }
            ],
            "thresholds": [
              {"color": "red", "value": 0},
              {"color": "yellow", "value": 95},
              {"color": "green", "value": 99}
            ]
          },
          {
            "title": "Migration Progress",
            "type": "graph",
            "targets": [
              {
                "expr": "migration_progress_percentage",
                "legendFormat": "Progress %"
              }
            ]
          },
          {
            "title": "Sync Operation Success Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(sync_operation_success_total[5m]) / rate(sync_operation_total[5m]) * 100",
                "legendFormat": "Success Rate %"
              }
            ]
          },
          {
            "title": "Data Integrity Issues",
            "type": "table",
            "targets": [
              {
                "expr": "duplicate_sync_identifiers_count",
                "legendFormat": "Duplicate Sync IDs"
              },
              {
                "expr": "invalid_sync_identifiers_count", 
                "legendFormat": "Invalid Sync IDs"
              },
              {
                "expr": "orphaned_file_attachments_count",
                "legendFormat": "Orphaned Files"
              }
            ]
          }
        ]
      }
    }
```

## Alert Rules Configuration

### Critical Alerts

```yaml
# monitoring/alerts/sync_identifier_critical.yaml
groups:
  - name: sync_identifier_critical
    rules:
      - alert: SyncIdentifierCoverageLow
        expr: sync_identifier_coverage_percentage < 95
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Sync identifier coverage is below 95%"
          description: "Only {{ $value }}% of documents have sync identifiers. Target is 100%."
          runbook_url: "https://docs.company.com/runbooks/sync-identifier-coverage"

      - alert: DuplicateSyncIdentifiers
        expr: duplicate_sync_identifiers_count > 0
        for: 0m
        labels:
          severity: critical
        annotations:
          summary: "Duplicate sync identifiers detected"
          description: "{{ $value }} duplicate sync identifiers found. This violates data integrity."
          runbook_url: "https://docs.company.com/runbooks/duplicate-sync-ids"

      - alert: MigrationFailureRateHigh
        expr: rate(migration_failures_total[5m]) / rate(migration_attempts_total[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Migration failure rate is above 5%"
          description: "{{ $value | humanizePercentage }} of migrations are failing."
          runbook_url: "https://docs.company.com/runbooks/migration-failures"
```

### Warning Alerts

```yaml
# monitoring/alerts/sync_identifier_warning.yaml
groups:
  - name: sync_identifier_warning
    rules:
      - alert: SyncOperationLatencyHigh
        expr: histogram_quantile(0.95, rate(sync_operation_duration_seconds_bucket[5m])) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Sync operation latency is high"
          description: "95th percentile sync operation latency is {{ $value }}s. Target is <5s."

      - alert: ConflictResolutionRateHigh
        expr: rate(conflict_resolution_total[5m]) / rate(sync_operation_total[5m]) > 0.02
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Conflict resolution rate is above 2%"
          description: "{{ $value | humanizePercentage }} of sync operations require conflict resolution."

      - alert: InvalidSyncIdentifiers
        expr: invalid_sync_identifiers_count > 0
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Invalid sync identifiers detected"
          description: "{{ $value }} invalid sync identifiers found."
```

## Health Check Endpoints

### Migration Health Check

```dart
// lib/services/health_check_service.dart
class HealthCheckService {
  Future<Map<String, dynamic>> getSyncIdentifierHealth() async {
    final migrationManager = MigrationManager();
    final validation = await migrationManager.validateMigration();
    
    return {
      'sync_identifier_health': {
        'status': validation.isValid ? 'healthy' : 'unhealthy',
        'coverage_percentage': validation.documentsWithSyncId / validation.totalDocuments * 100,
        'total_documents': validation.totalDocuments,
        'documents_with_sync_id': validation.documentsWithSyncId,
        'documents_without_sync_id': validation.documentsWithoutSyncId,
        'issues': validation.issues,
        'last_checked': DateTime.now().toIso8601String(),
      }
    };
  }

  Future<Map<String, dynamic>> getMigrationStatus() async {
    final migrationManager = MigrationManager();
    final progress = migrationManager.currentProgress;
    
    return {
      'migration_status': {
        'status': progress.status.toString(),
        'progress_percentage': progress.progressPercentage * 100,
        'total_documents': progress.totalDocuments,
        'migrated_documents': progress.migratedDocuments,
        'failed_documents': progress.failedDocuments,
        'current_phase': progress.currentPhase,
        'error': progress.error,
        'last_updated': DateTime.now().toIso8601String(),
      }
    };
  }
}
```

### API Health Endpoints

```dart
// Add to existing API routes
app.get('/health/sync-identifiers', (req, res) async {
  final healthCheck = HealthCheckService();
  final health = await healthCheck.getSyncIdentifierHealth();
  
  final statusCode = health['sync_identifier_health']['status'] == 'healthy' ? 200 : 503;
  res.status(statusCode).json(health);
});

app.get('/health/migration', (req, res) async {
  final healthCheck = HealthCheckService();
  final status = await healthCheck.getMigrationStatus();
  
  res.json(status);
});
```

## Log Aggregation and Analysis

### Structured Logging

```dart
// Enhanced logging for sync identifier operations
class SyncIdentifierLogger {
  static void logMigrationStart(int totalDocuments) {
    _logger.info('Migration started', extra: {
      'event_type': 'migration_start',
      'total_documents': totalDocuments,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void logMigrationProgress(MigrationManagerProgress progress) {
    _logger.info('Migration progress', extra: {
      'event_type': 'migration_progress',
      'status': progress.status.toString(),
      'progress_percentage': progress.progressPercentage * 100,
      'migrated_documents': progress.migratedDocuments,
      'failed_documents': progress.failedDocuments,
      'current_phase': progress.currentPhase,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void logSyncOperation(String syncId, SyncOperationType operation, bool success, Duration duration) {
    _logger.info('Sync operation completed', extra: {
      'event_type': 'sync_operation',
      'sync_id': syncId,
      'operation_type': operation.toString(),
      'success': success,
      'duration_ms': duration.inMilliseconds,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static void logDataIntegrityIssue(String issueType, Map<String, dynamic> details) {
    _logger.error('Data integrity issue detected', extra: {
      'event_type': 'data_integrity_issue',
      'issue_type': issueType,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
}
```

### Log Analysis Queries

```sql
-- Find migration failures
SELECT 
  timestamp,
  details->>'document_id' as document_id,
  details->>'error' as error_message
FROM logs 
WHERE event_type = 'migration_failure'
  AND timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Analyze sync operation performance
SELECT 
  operation_type,
  AVG(CAST(details->>'duration_ms' AS INTEGER)) as avg_duration_ms,
  COUNT(*) as operation_count,
  SUM(CASE WHEN success = true THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate
FROM logs 
WHERE event_type = 'sync_operation'
  AND timestamp > NOW() - INTERVAL '1 hour'
GROUP BY operation_type;

-- Identify data integrity issues
SELECT 
  issue_type,
  COUNT(*) as issue_count,
  MAX(timestamp) as last_occurrence
FROM logs 
WHERE event_type = 'data_integrity_issue'
  AND timestamp > NOW() - INTERVAL '24 hours'
GROUP BY issue_type;
```

## Performance Monitoring

### Database Performance

```sql
-- Monitor sync identifier query performance
EXPLAIN ANALYZE SELECT * FROM documents WHERE syncId = 'uuid-here';

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes 
WHERE indexname LIKE '%sync%';

-- Monitor migration query performance
SELECT 
  query,
  mean_time,
  calls,
  total_time
FROM pg_stat_statements 
WHERE query LIKE '%syncId%'
ORDER BY mean_time DESC;
```

### Application Performance

```dart
// Performance monitoring for sync operations
class SyncPerformanceMonitor {
  static final Map<String, List<Duration>> _operationTimes = {};

  static void recordOperation(String operation, Duration duration) {
    _operationTimes.putIfAbsent(operation, () => []).add(duration);
    
    // Keep only last 100 measurements
    if (_operationTimes[operation]!.length > 100) {
      _operationTimes[operation]!.removeAt(0);
    }
  }

  static Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final entry in _operationTimes.entries) {
      final times = entry.value;
      if (times.isEmpty) continue;
      
      times.sort();
      final p50 = times[times.length ~/ 2].inMilliseconds;
      final p95 = times[(times.length * 0.95).round()].inMilliseconds;
      final avg = times.map((d) => d.inMilliseconds).reduce((a, b) => a + b) / times.length;
      
      stats[entry.key] = {
        'count': times.length,
        'avg_ms': avg.round(),
        'p50_ms': p50,
        'p95_ms': p95,
      };
    }
    
    return stats;
  }
}
```

## Automated Testing in Production

### Canary Testing

```dart
// Automated canary testing for sync identifier functionality
class SyncIdentifierCanaryTest {
  Future<bool> runCanaryTest() async {
    try {
      // Test 1: Create document with sync identifier
      final testDoc = await _createTestDocument();
      if (testDoc.syncId == null || testDoc.syncId!.isEmpty) {
        return false;
      }

      // Test 2: Validate sync identifier format
      if (!SyncIdentifierGenerator.isValid(testDoc.syncId!)) {
        return false;
      }

      // Test 3: Test document matching
      final matchedDoc = await _findDocumentBySyncId(testDoc.syncId!);
      if (matchedDoc == null || matchedDoc.id != testDoc.id) {
        return false;
      }

      // Test 4: Test sync operation
      final syncResult = await _testSyncOperation(testDoc);
      if (!syncResult) {
        return false;
      }

      // Cleanup
      await _cleanupTestDocument(testDoc);
      
      return true;
    } catch (e) {
      _logger.error('Canary test failed: $e');
      return false;
    }
  }
}
```

### Synthetic Monitoring

```yaml
# monitoring/synthetic/sync_identifier_tests.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sync-identifier-synthetic-tests
data:
  test_config.yaml: |
    tests:
      - name: sync_identifier_generation
        interval: 60s
        timeout: 10s
        steps:
          - action: generate_sync_id
            validate: uuid_v4_format
          - action: validate_uniqueness
            validate: no_duplicates

      - name: document_sync_workflow
        interval: 300s
        timeout: 30s
        steps:
          - action: create_document
            validate: has_sync_id
          - action: sync_document
            validate: sync_success
          - action: verify_remote_document
            validate: sync_id_matches

      - name: migration_health_check
        interval: 600s
        timeout: 60s
        steps:
          - action: check_migration_status
            validate: all_documents_migrated
          - action: validate_data_integrity
            validate: no_integrity_issues
```

## Incident Response Procedures

### Runbook: Sync Identifier Coverage Drop

1. **Immediate Actions**
   - Check migration service status
   - Verify database connectivity
   - Review recent deployments

2. **Investigation Steps**
   - Query documents without sync identifiers
   - Check migration logs for failures
   - Validate sync identifier generation

3. **Resolution Steps**
   - Restart migration service if needed
   - Re-run migration for failed documents
   - Verify coverage returns to 100%

### Runbook: Duplicate Sync Identifiers

1. **Immediate Actions**
   - Stop sync operations
   - Identify affected documents
   - Prevent further duplicates

2. **Investigation Steps**
   - Find root cause of duplication
   - Check UUID generation service
   - Review concurrent operation logs

3. **Resolution Steps**
   - Generate new sync identifiers for duplicates
   - Update all references
   - Resume sync operations

## Conclusion

This monitoring and alerting configuration provides comprehensive visibility into the sync identifier refactor deployment. Regular monitoring of these metrics will ensure system health, data integrity, and optimal performance throughout the migration and beyond.

The configuration should be reviewed and updated based on production experience and evolving requirements.