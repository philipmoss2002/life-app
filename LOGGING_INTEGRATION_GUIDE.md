# Logging Integration Guide

This guide shows how to integrate the comprehensive logging system into file operations.

## Quick Start

### 1. Simple File Operation Tracking

```dart
import 'package:household_docs_app/utils/file_operation_logger.dart';

// Create a tracker for your operation
final tracker = FileOperationTracker(
  operation: 'uploadFile',
  userIdentifier: userSub,
  syncId: syncId,
  fileName: fileName,
  s3Key: s3Key,
  fileSizeBytes: file.lengthSync(),
);

// Execute with automatic logging
final result = await tracker.track(() async {
  return await Amplify.Storage.uploadFile(
    localFile: file,
    key: s3Key,
  );
});
```

### 2. File Operation with Retry Support

```dart
// Execute with automatic retries and logging
final result = await tracker.trackWithRetry(() async {
  return await Amplify.Storage.uploadFile(
    localFile: file,
    key: s3Key,
  );
}, maxRetries: 3);
```

### 3. Manual Logging

```dart
import 'package:household_docs_app/services/log_service.dart';

// Log a file operation
LogService().logFileOperation(
  operation: 'downloadFile',
  outcome: 'success',
  userIdentifier: userSub,
  syncId: syncId,
  fileName: fileName,
  s3Key: s3Key,
  fileSizeBytes: downloadedBytes,
);

// Log a failure with error details
LogService().logFileOperation(
  operation: 'uploadFile',
  outcome: 'failure',
  userIdentifier: userSub,
  syncId: syncId,
  fileName: fileName,
  s3Key: s3Key,
  errorCode: 'AccessDenied',
  errorMessage: 'User does not have permission to upload',
  retryAttempt: 2,
);
```

### 4. Audit Logging for Security Events

```dart
// Log a security-sensitive operation
LogService().logAuditEvent(
  eventType: 'FILE_ACCESS',
  action: 'download',
  userIdentifier: userSub,
  resourceId: s3Key,
  outcome: 'success',
  details: 'User downloaded sensitive document',
  metadata: {
    'ipAddress': '192.168.1.1',
    'deviceId': 'device-123',
  },
);

// Log authentication events
LogService().logAuditEvent(
  eventType: 'AUTHENTICATION',
  action: 'login',
  userIdentifier: userSub,
  outcome: 'success',
  details: 'User logged in successfully',
);
```

### 5. Performance Metrics

```dart
final stopwatch = Stopwatch()..start();

// Perform operation
await uploadFile();

stopwatch.stop();

// Record performance metric
LogService().recordPerformanceMetric(
  operation: 'uploadFile',
  duration: stopwatch.elapsed,
  userIdentifier: userSub,
  resourceId: s3Key,
  dataSizeBytes: fileSize,
  success: true,
  additionalMetrics: {
    'compressionRatio': 0.75,
    'networkType': 'wifi',
  },
);
```

## Integration Examples

### Example 1: PersistentFileService Integration

```dart
class PersistentFileService {
  Future<String> uploadFile({
    required String syncId,
    required File file,
    required String fileName,
  }) async {
    final userSub = await _getUserPoolSub();
    final s3Key = generateS3Path(userSub, syncId, fileName);
    
    final tracker = FileOperationTracker(
      operation: 'uploadFile',
      userIdentifier: userSub,
      syncId: syncId,
      fileName: fileName,
      s3Key: s3Key,
      fileSizeBytes: await file.length(),
    );

    return await tracker.trackWithRetry(() async {
      final result = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(file.path),
        key: s3Key,
        options: const StorageUploadFileOptions(
          accessLevel: StorageAccessLevel.private,
        ),
      );
      
      // Log audit event for file upload
      LogService().logAuditEvent(
        eventType: 'FILE_UPLOAD',
        action: 'create',
        userIdentifier: userSub,
        resourceId: s3Key,
        outcome: 'success',
        details: 'File uploaded successfully',
      );
      
      return result.uploadedItem.key;
    }, maxRetries: 3);
  }
}
```

### Example 2: Migration Operation Logging

```dart
Future<Map<String, dynamic>> migrateExistingUser({
  bool forceReMigration = false,
}) async {
  final logger = FileOperationLogger();
  
  logger.startOperation(
    operation: 'migrateExistingUser',
    userIdentifier: userSub,
  );

  try {
    // Perform migration
    final result = await _performMigration(forceReMigration);
    
    logger.logSuccess(
      additionalData: {
        'filesProcessed': result['filesProcessed'],
        'filesMigrated': result['filesMigrated'],
        'forceReMigration': forceReMigration,
      },
    );
    
    // Log audit event
    LogService().logAuditEvent(
      eventType: 'MIGRATION',
      action: 'migrateUser',
      userIdentifier: userSub,
      outcome: 'success',
      details: 'User files migrated successfully',
      metadata: result,
    );
    
    return result;
  } catch (e) {
    logger.logFailure(
      errorMessage: e.toString(),
      errorCode: _extractErrorCode(e),
    );
    
    rethrow;
  }
}
```

### Example 3: Error Handling with Logging

```dart
Future<void> downloadFile(String s3Key) async {
  final tracker = FileOperationTracker(
    operation: 'downloadFile',
    userIdentifier: userSub,
    s3Key: s3Key,
  );

  try {
    await tracker.track(() async {
      final result = await Amplify.Storage.downloadFile(
        key: s3Key,
        localFile: localFile,
        options: const StorageDownloadFileOptions(
          accessLevel: StorageAccessLevel.private,
        ),
      );
      
      return result;
    });
  } on StorageException catch (e) {
    // Log specific error details
    LogService().logFileOperation(
      operation: 'downloadFile',
      outcome: 'failure',
      userIdentifier: userSub,
      s3Key: s3Key,
      errorCode: e.message.contains('AccessDenied') 
        ? 'AccessDenied' 
        : 'StorageException',
      errorMessage: e.message,
      additionalData: {
        'recoverySuggestion': e.recoverySuggestion,
        'underlyingException': e.underlyingException?.toString(),
      },
    );
    
    rethrow;
  }
}
```

## Querying Logs

### Get Recent File Operations

```dart
// Get file operations from last 60 minutes
final recentOps = LogService().getRecentFileOperationLogs(60);

for (final op in recentOps) {
  print('${op.operation}: ${op.outcome} at ${op.timestamp}');
}
```

### Get Failed Operations

```dart
// Get all failed operations
final failures = LogService().getFileOperationLogsByOutcome('failure');

print('Total failures: ${failures.length}');
for (final failure in failures) {
  print('${failure.operation} failed: ${failure.errorMessage}');
  if (failure.errorCode != null) {
    print('  Error code: ${failure.errorCode}');
  }
  if (failure.retryAttempt != null) {
    print('  Retry attempt: ${failure.retryAttempt}');
  }
}
```

### Get User-Specific Logs

```dart
// Get all operations for a specific user
final userOps = LogService().getFileOperationLogsByUser(userSub);

print('User $userSub performed ${userOps.length} operations');
```

### Get Performance Statistics

```dart
// Get average duration for uploads
final avgDuration = LogService().getAverageOperationDuration('uploadFile');
if (avgDuration != null) {
  print('Average upload time: ${avgDuration.inMilliseconds}ms');
}

// Get success rate
final successRate = LogService().getFileOperationSuccessRate();
print('Success rate: ${(successRate * 100).toStringAsFixed(1)}%');

// Get comprehensive statistics
final stats = LogService().getStatistics();
print(stats);
```

### Get Audit Logs

```dart
// Get all authentication events
final authEvents = LogService().getAuditLogsByEventType('AUTHENTICATION');

// Get recent security events (last 24 hours)
final recentAudits = LogService().getRecentAuditLogs(24 * 60);

// Get user-specific audit trail
final userAudits = LogService().getAuditLogsByUser(userSub);
```

## Best Practices

### 1. Always Track File Operations

Use `FileOperationTracker` for all file operations to ensure consistent logging:

```dart
// ✅ Good
final tracker = FileOperationTracker(operation: 'uploadFile', ...);
await tracker.track(() => uploadToS3());

// ❌ Avoid
await uploadToS3(); // No logging
```

### 2. Use Retry Support for Network Operations

```dart
// ✅ Good - automatic retry with logging
await tracker.trackWithRetry(() => uploadToS3(), maxRetries: 3);

// ❌ Avoid - manual retry without proper logging
for (int i = 0; i < 3; i++) {
  try {
    await uploadToS3();
    break;
  } catch (e) {
    if (i == 2) rethrow;
  }
}
```

### 3. Log Security-Sensitive Operations

Always use audit logging for security-sensitive operations:

```dart
// ✅ Good
LogService().logAuditEvent(
  eventType: 'FILE_ACCESS',
  action: 'delete',
  userIdentifier: userSub,
  resourceId: s3Key,
  outcome: 'success',
);

// ❌ Avoid
LogService().log('File deleted'); // Not structured, no audit trail
```

### 4. Include Context in Additional Data

```dart
// ✅ Good - rich context
logger.logSuccess(
  additionalData: {
    'fileType': 'pdf',
    'compressionUsed': true,
    'networkType': 'wifi',
    'deviceType': 'mobile',
  },
);

// ❌ Avoid - minimal context
logger.logSuccess();
```

### 5. Monitor Performance Regularly

```dart
// Check for slow operations
final recentMetrics = LogService().getRecentPerformanceMetrics(60);
final slowOps = recentMetrics.where((m) => m.duration.inSeconds > 5);

if (slowOps.isNotEmpty) {
  print('⚠️ ${slowOps.length} slow operations detected');
}
```

## Troubleshooting

### High Memory Usage

If logs are consuming too much memory, adjust the limits:

```dart
// In log_service.dart
static const int maxLogs = 500; // Reduce from 1000
static const int maxFileOperationLogs = 250; // Reduce from 500
```

### Missing Logs

Ensure operations are properly tracked:

```dart
// Check if tracking is active
if (logger.isTracking) {
  print('Operation is being tracked');
}

// Check elapsed time
print('Elapsed: ${logger.elapsed}');
```

### Performance Impact

The logging system is designed to be lightweight, but for high-frequency operations:

```dart
// Batch log queries instead of individual calls
final allOps = LogService().getFileOperationLogs();
// Process in batch
```

## Summary

The comprehensive logging system provides:

- ✅ Structured logging for all file operations
- ✅ Automatic performance tracking
- ✅ Security audit trails
- ✅ Error tracking with AWS error codes
- ✅ Retry attempt logging
- ✅ Privacy-preserving user masking
- ✅ Comprehensive query methods
- ✅ Statistics and success rate tracking

Use `FileOperationTracker` for simple integration and automatic logging of all file operations.
