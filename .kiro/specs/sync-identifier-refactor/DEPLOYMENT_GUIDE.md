# Sync Identifier Refactor - Deployment Guide

## Overview

This document provides comprehensive guidance for deploying the sync identifier refactor to production. The refactor introduces universal sync identifiers (UUID v4) to replace database-specific IDs, enabling reliable document synchronization across local SQLite and remote DynamoDB storage.

## Pre-Deployment Validation

### 1. Test Suite Validation

Run the complete test suite to ensure all functionality is working:

```bash
flutter test --reporter expanded
```

**Expected Results:**
- All property-based tests should pass (Properties 1-10)
- Unit tests should have >95% pass rate
- Integration tests should validate end-to-end workflows
- Migration tests should confirm data preservation

### 2. Property-Based Test Validation

Specifically validate the 10 correctness properties:

```bash
# Property 1: Sync Identifier Uniqueness
flutter test test/services/property_33_sync_identifier_uniqueness_test.dart

# Property 2: Sync Identifier Immutability  
flutter test test/services/property_2_sync_identifier_immutability_test.dart

# Property 3: Document Matching by Sync Identifier
flutter test test/services/property_3_document_matching_by_sync_identifier_test.dart

# Property 4: File Path Sync Identifier Consistency
flutter test test/services/property_4_file_path_sync_identifier_consistency_test.dart

# Property 5: Deletion Tombstone Preservation
flutter test test/services/property_5_deletion_tombstone_preservation_test.dart

# Property 6: Migration Data Preservation
flutter test test/services/property_6_migration_data_preservation_test.dart

# Property 7: Sync Queue Consolidation
flutter test test/services/property_7_sync_queue_consolidation_test.dart

# Property 8: Conflict Resolution Identity Preservation
flutter test test/services/property_8_conflict_resolution_identity_preservation_test.dart

# Property 9: API Sync Identifier Consistency
flutter test test/services/property_9_api_sync_identifier_consistency_test.dart

# Property 10: Validation Rejection
flutter test test/services/property_10_validation_rejection_test.dart
```

### 3. Migration Completeness Validation

Validate that the migration system is working correctly:

```bash
flutter test test/integration/migration_integration_test.dart
flutter test test/services/migration_manager_test.dart
```

## Database Schema Changes

### Local Database (SQLite)

The following schema changes have been implemented:

```sql
-- Add syncId column to documents table
ALTER TABLE documents ADD COLUMN syncId TEXT;

-- Create unique index on syncId (after migration)
CREATE UNIQUE INDEX idx_documents_sync_id ON documents(syncId) WHERE syncId IS NOT NULL;

-- Create DocumentTombstone table for deletion tracking
CREATE TABLE document_tombstones (
    syncId TEXT PRIMARY KEY,
    userId TEXT NOT NULL,
    deletedAt TEXT NOT NULL,
    deletedBy TEXT NOT NULL,
    reason TEXT NOT NULL
);

-- Update FileAttachment table to reference syncId
ALTER TABLE file_attachments ADD COLUMN documentSyncId TEXT;
CREATE INDEX idx_file_attachments_sync_id ON file_attachments(documentSyncId);
```

### Remote Database (DynamoDB)

Update the DynamoDB schema to use syncId as partition key:

```json
{
  "TableName": "Documents",
  "KeySchema": [
    {
      "AttributeName": "syncId",
      "KeyType": "HASH"
    }
  ],
  "AttributeDefinitions": [
    {
      "AttributeName": "syncId",
      "AttributeType": "S"
    },
    {
      "AttributeName": "userId",
      "AttributeType": "S"
    }
  ],
  "GlobalSecondaryIndexes": [
    {
      "IndexName": "UserIndex",
      "KeySchema": [
        {
          "AttributeName": "userId",
          "KeyType": "HASH"
        }
      ]
    }
  ]
}
```

## Deployment Steps

### Phase 1: Pre-Migration Preparation

1. **Backup Data**
   - Create full backup of local SQLite databases
   - Export DynamoDB table data
   - Backup S3 file attachments

2. **Deploy Application Update**
   - Deploy new application version with sync identifier support
   - Ensure backward compatibility is enabled
   - Monitor for any immediate issues

### Phase 2: Migration Execution

1. **Local Document Migration**
   ```dart
   final migrationManager = MigrationManager();
   final result = await migrationManager.migrateLocalDocuments();
   ```

2. **Validation**
   ```dart
   final validation = await migrationManager.validateMigration();
   if (!validation.isValid) {
     // Handle migration issues
   }
   ```

3. **Remote Document Re-creation**
   ```dart
   final remoteResult = await migrationManager.recreateRemoteDocuments();
   ```

### Phase 3: Post-Migration Validation

1. **Data Integrity Checks**
   - Verify all documents have sync identifiers
   - Confirm file attachments are accessible
   - Test sync operations end-to-end

2. **Performance Monitoring**
   - Monitor sync operation performance
   - Check database query performance
   - Validate S3 file access patterns

## Monitoring and Alerting

### Key Metrics to Monitor

1. **Migration Metrics**
   - Documents with sync identifiers: Should be 100%
   - Migration failure rate: Should be <1%
   - Migration completion time: Baseline for future migrations

2. **Sync Performance**
   - Sync operation success rate: Should be >99%
   - Average sync time: Should improve with sync identifiers
   - Conflict resolution rate: Should decrease

3. **Data Integrity**
   - Duplicate sync identifiers: Should be 0
   - Orphaned file attachments: Should be 0
   - Tombstone cleanup: Should run every 90 days

### Alerting Rules

```yaml
# Migration Alerts
- alert: MigrationFailureRate
  expr: migration_failure_rate > 0.01
  for: 5m
  annotations:
    summary: "High migration failure rate detected"

- alert: DocumentsWithoutSyncId
  expr: documents_without_sync_id > 0
  for: 1m
  annotations:
    summary: "Documents found without sync identifiers"

# Sync Performance Alerts  
- alert: SyncFailureRate
  expr: sync_failure_rate > 0.01
  for: 5m
  annotations:
    summary: "High sync failure rate detected"

- alert: DuplicateSyncIds
  expr: duplicate_sync_ids > 0
  for: 1m
  annotations:
    summary: "Duplicate sync identifiers detected"
```

## Rollback Procedures

### Emergency Rollback

If critical issues are detected:

1. **Immediate Actions**
   - Revert to previous application version
   - Disable sync operations
   - Restore from backup if necessary

2. **Data Recovery**
   - Restore SQLite databases from backup
   - Restore DynamoDB table from backup
   - Verify file attachment accessibility

### Partial Rollback

For non-critical issues:

1. **Disable New Features**
   - Disable sync identifier validation
   - Fall back to legacy matching logic
   - Continue with existing sync identifiers

2. **Gradual Recovery**
   - Fix identified issues
   - Re-enable features incrementally
   - Monitor for stability

## Performance Considerations

### Database Performance

1. **Index Optimization**
   - Ensure syncId indexes are created
   - Monitor query performance
   - Consider composite indexes for common queries

2. **Query Patterns**
   - Use sync identifiers for document lookups
   - Batch operations where possible
   - Implement connection pooling

### S3 Performance

1. **File Path Structure**
   - New structure: `{userId}/{syncId}/{filename}`
   - Enables better partitioning
   - Improves access patterns

2. **Migration Strategy**
   - Migrate file paths gradually
   - Maintain backward compatibility during transition
   - Monitor access patterns

## Security Considerations

### Sync Identifier Security

1. **UUID Generation**
   - Use cryptographically secure random number generator
   - Validate UUID v4 format
   - Prevent predictable identifiers

2. **Access Control**
   - Validate user ownership of sync identifiers
   - Implement proper authorization checks
   - Audit sync identifier usage

### Data Protection

1. **Encryption**
   - Maintain encryption at rest and in transit
   - Ensure sync identifiers don't expose sensitive data
   - Implement proper key management

2. **Privacy**
   - Sync identifiers should not be personally identifiable
   - Implement proper data retention policies
   - Support user data deletion requests

## Testing in Production

### Canary Deployment

1. **Gradual Rollout**
   - Deploy to 5% of users initially
   - Monitor key metrics for 24 hours
   - Gradually increase to 100% over 1 week

2. **Feature Flags**
   - Use feature flags to control sync identifier features
   - Enable gradual feature rollout
   - Quick rollback capability

### A/B Testing

1. **Performance Comparison**
   - Compare sync performance before/after
   - Measure user experience metrics
   - Validate improvement hypotheses

2. **Error Rate Monitoring**
   - Monitor error rates by user cohort
   - Compare legacy vs new sync logic
   - Identify any regression patterns

## Success Criteria

### Technical Success

- [ ] All documents have valid sync identifiers
- [ ] Sync operations use sync identifiers consistently
- [ ] File attachments accessible via sync identifier paths
- [ ] Migration completed with <1% failure rate
- [ ] All property-based tests passing
- [ ] Performance improved or maintained

### Business Success

- [ ] Reduced sync conflicts and duplicates
- [ ] Improved user experience with reliable sync
- [ ] Reduced support tickets related to sync issues
- [ ] Successful multi-device document access
- [ ] Maintained data integrity across all operations

## Post-Deployment Tasks

### Week 1
- [ ] Monitor all key metrics daily
- [ ] Review error logs for any new issues
- [ ] Validate migration completeness
- [ ] Collect user feedback

### Week 2-4
- [ ] Analyze performance improvements
- [ ] Optimize based on production patterns
- [ ] Plan cleanup of legacy code
- [ ] Document lessons learned

### Month 2-3
- [ ] Remove backward compatibility code
- [ ] Optimize database schemas
- [ ] Implement advanced sync features
- [ ] Plan next iteration improvements

## Support and Troubleshooting

### Common Issues

1. **Migration Failures**
   - Check database connectivity
   - Verify user authentication
   - Review error logs for specific failures

2. **Sync Identifier Conflicts**
   - Validate UUID generation
   - Check for system clock issues
   - Verify random number generator

3. **File Access Issues**
   - Verify S3 key generation
   - Check file migration status
   - Validate user permissions

### Debug Tools

1. **Migration Status**
   ```dart
   final status = await MigrationManager().getMigrationStatusSummary();
   ```

2. **Sync Identifier Validation**
   ```dart
   final isValid = SyncIdentifierGenerator.isValid(syncId);
   ```

3. **Analytics Dashboard**
   - View sync identifier coverage
   - Monitor migration progress
   - Track performance metrics

## Conclusion

The sync identifier refactor represents a significant architectural improvement that will enable reliable document synchronization across all storage systems. Careful deployment following this guide will ensure a smooth transition while maintaining data integrity and user experience.

For questions or issues during deployment, refer to the troubleshooting section or contact the development team.