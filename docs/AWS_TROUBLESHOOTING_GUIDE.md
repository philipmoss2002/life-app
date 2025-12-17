# AWS Operations Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting information for real AWS operations in the Household Docs App cloud sync implementation. It covers common issues, diagnostic steps, and solutions for AWS Amplify, DynamoDB, S3, and Cognito operations.

## Common Issues and Solutions

### 1. Authentication Issues

#### Issue: "User is not authenticated" Error

**Symptoms:**
- API calls return 401 Unauthorized
- GraphQL operations fail with authentication errors
- Sync operations stop working after some time

**Diagnostic Steps:**
```dart
// Check authentication status
final authSession = await Amplify.Auth.fetchAuthSession();
print('Is signed in: ${authSession.isSignedIn}');

if (authSession.isSignedIn) {
  final tokens = authSession.userPoolTokensResult.value;
  print('Access token expires: ${tokens.accessToken.expiresAt}');
  print('ID token expires: ${tokens.idToken.expiresAt}');
}
```

**Solutions:**

1. **Token Refresh:**
```dart
try {
  final result = await Amplify.Auth.fetchAuthSession(
    options: const FetchAuthSessionOptions(forceRefresh: true)
  );
  
  if (result.isSignedIn) {
    // Retry the failed operation
    await retryFailedOperation();
  }
} catch (e) {
  // Redirect to sign-in if refresh fails
  await navigateToSignIn();
}
```

2. **Automatic Token Management:**
```dart
class AuthTokenManager {
  Timer? _refreshTimer;
  
  void startTokenRefreshTimer() {
    _refreshTimer = Timer.periodic(Duration(minutes: 50), (_) async {
      try {
        await Amplify.Auth.fetchAuthSession(
          options: const FetchAuthSessionOptions(forceRefresh: true)
        );
      } catch (e) {
        print('Token refresh failed: $e');
      }
    });
  }
}
```

#### Issue: "Access Denied" Error

**Symptoms:**
- 403 Forbidden responses
- User can authenticate but cannot access resources
- GraphQL operations fail with authorization errors

**Diagnostic Steps:**
```dart
// Check user attributes
final user = await Amplify.Auth.getCurrentUser();
print('User ID: ${user.userId}');
print('Username: ${user.username}');

// Verify user groups (if using)
final attributes = await Amplify.Auth.fetchUserAttributes();
for (final attr in attributes) {
  print('${attr.userAttributeKey}: ${attr.value}');
}
```

**Solutions:**

1. **Verify IAM Policies:**
   - Check that authenticated users have proper permissions
   - Ensure Cognito Identity Pool has correct roles
   - Verify resource-based policies (S3 bucket, DynamoDB table)

2. **Check GraphQL Authorization Rules:**
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!
  userId: String! @index(name: "byUserId")
  # ... other fields
}
```

### 2. GraphQL API Issues

#### Issue: GraphQL Mutations Failing

**Symptoms:**
- Mutations return errors but queries work
- "ValidationException" errors
- Schema validation failures

**Diagnostic Steps:**
```dart
// Enable detailed GraphQL logging
await Amplify.addPlugin(AmplifyAPI(
  options: APIPluginOptions(
    modelProvider: ModelProvider.instance,
  ),
));

// Check mutation request
final request = ModelMutations.create(document);
print('Mutation: ${request.document}');
print('Variables: ${request.variables}');

try {
  final response = await Amplify.API.mutate(request: request).response;
  if (response.hasErrors) {
    for (final error in response.errors) {
      print('GraphQL Error: ${error.message}');
      print('Error Type: ${error.extensions?['errorType']}');
      print('Path: ${error.path}');
    }
  }
} catch (e) {
  print('API Error: $e');
}
```

**Solutions:**

1. **Validate Input Data:**
```dart
void validateDocument(Document document) {
  if (document.title.isEmpty) {
    throw ValidationException('Title is required');
  }
  
  if (document.category.isEmpty) {
    throw ValidationException('Category is required');
  }
  
  if (document.userId.isEmpty) {
    throw ValidationException('User ID is required');
  }
}
```

2. **Handle Schema Mismatches:**
```dart
// Ensure model matches GraphQL schema
extension DocumentValidation on Document {
  Map<String, dynamic> toGraphQLInput() {
    return {
      'title': title,
      'category': category,
      'userId': userId,
      'filePaths': filePaths,
      'renewalDate': renewalDate?.toIso8601String(),
      'notes': notes,
      'version': version,
      'syncState': syncState.name,
      'deleted': false, // Ensure required fields are set
    };
  }
}
```

#### Issue: GraphQL Subscriptions Not Working

**Symptoms:**
- Real-time updates not received
- Subscription connection fails
- WebSocket connection errors

**Diagnostic Steps:**
```dart
// Test subscription connection
final subscription = ModelSubscriptions.onCreate(Document.classType);

final stream = Amplify.API.subscribe(
  request: subscription,
  onEstablished: () => print('Subscription established'),
);

stream.listen(
  (event) => print('Received: ${event.data}'),
  onError: (error) => print('Subscription error: $error'),
  onDone: () => print('Subscription closed'),
);
```

**Solutions:**

1. **Check Network Connectivity:**
```dart
class SubscriptionManager {
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  
  void startSubscription() {
    _subscription = Amplify.API.subscribe(
      request: ModelSubscriptions.onCreate(Document.classType),
      onEstablished: () {
        print('Subscription established');
        _reconnectTimer?.cancel();
      },
    ).listen(
      (event) => _handleUpdate(event),
      onError: (error) {
        print('Subscription error: $error');
        _scheduleReconnect();
      },
    );
  }
  
  void _scheduleReconnect() {
    _reconnectTimer = Timer(Duration(seconds: 5), () {
      _subscription?.cancel();
      startSubscription();
    });
  }
}
```

2. **Filter Subscriptions Properly:**
```dart
// Subscribe only to user's documents
final subscription = ModelSubscriptions.onCreate(Document.classType)
    .where(Document.USERID.eq(currentUserId));
```

### 3. DynamoDB Issues

#### Issue: "ConditionalCheckFailedException"

**Symptoms:**
- Updates fail with conditional check errors
- Version conflicts not handled properly
- Optimistic locking failures

**Diagnostic Steps:**
```dart
// Check current item version
try {
  final current = await Amplify.API.query(
    request: ModelQueries.get(Document.classType, documentId)
  ).response;
  
  if (current.data != null) {
    print('Current version: ${current.data!.version}');
    print('Attempting version: ${document.version}');
  }
} catch (e) {
  print('Failed to fetch current version: $e');
}
```

**Solutions:**

1. **Implement Proper Version Handling:**
```dart
Future<void> updateDocumentWithVersionCheck(Document document) async {
  int maxRetries = 3;
  
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      // Get latest version
      final latest = await downloadDocument(document.id.toString());
      
      // Update with latest version
      final updatedDoc = document.copyWith(
        version: latest.version + 1,
        lastModified: DateTime.now(),
      );
      
      await _performUpdate(updatedDoc);
      return;
      
    } catch (e) {
      if (e.toString().contains('ConditionalCheckFailed') && 
          attempt < maxRetries - 1) {
        // Retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
        continue;
      }
      rethrow;
    }
  }
}
```

2. **Handle Version Conflicts:**
```dart
class VersionConflictHandler {
  Future<Document> resolveConflict(
    Document local, 
    Document remote
  ) async {
    // Compare timestamps
    if (local.lastModified.isAfter(remote.lastModified)) {
      return local.copyWith(version: remote.version + 1);
    } else {
      return remote;
    }
  }
}
```

#### Issue: "ProvisionedThroughputExceededException"

**Symptoms:**
- API calls fail with throttling errors
- Slow response times
- Intermittent failures during high load

**Solutions:**

1. **Implement Exponential Backoff:**
```dart
class DynamoDBRetryHandler {
  Future<T> executeWithBackoff<T>(Future<T> Function() operation) async {
    const maxRetries = 5;
    const baseDelay = Duration(milliseconds: 100);
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (_isThrottlingError(e) && attempt < maxRetries - 1) {
          final delay = Duration(
            milliseconds: baseDelay.inMilliseconds * (1 << attempt)
          );
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
    
    throw Exception('Max retries exceeded');
  }
  
  bool _isThrottlingError(dynamic error) {
    return error.toString().contains('ProvisionedThroughputExceeded') ||
           error.toString().contains('ThrottlingException');
  }
}
```

2. **Use Batch Operations:**
```dart
Future<void> batchWriteDocuments(List<Document> documents) async {
  const batchSize = 25; // DynamoDB batch limit
  
  for (int i = 0; i < documents.length; i += batchSize) {
    final batch = documents.skip(i).take(batchSize).toList();
    
    final requests = batch.map((doc) => 
      ModelMutations.create(doc.toAmplifyModel())
    ).toList();
    
    // Execute batch with retry
    await _executeWithRetry(() async {
      final futures = requests.map((req) => 
        Amplify.API.mutate(request: req).response
      );
      await Future.wait(futures);
    });
  }
}
```

### 4. S3 Storage Issues

#### Issue: File Upload Failures

**Symptoms:**
- File uploads timeout or fail
- Large files fail to upload
- Upload progress stops

**Diagnostic Steps:**
```dart
// Test S3 connectivity
try {
  final testKey = 'test-${DateTime.now().millisecondsSinceEpoch}.txt';
  final testContent = 'Test upload';
  
  await Amplify.Storage.uploadData(
    key: testKey,
    data: S3DataPayload.string(testContent),
  ).result;
  
  print('S3 upload test successful');
  
  // Clean up test file
  await Amplify.Storage.remove(key: testKey).result;
  
} catch (e) {
  print('S3 upload test failed: $e');
}
```

**Solutions:**

1. **Implement Multipart Upload for Large Files:**
```dart
Future<String> uploadLargeFile(String filePath, String s3Key) async {
  final file = File(filePath);
  final fileSize = await file.length();
  
  if (fileSize > 5 * 1024 * 1024) { // 5MB threshold
    return _uploadWithMultipart(file, s3Key);
  } else {
    return _uploadDirect(file, s3Key);
  }
}

Future<String> _uploadWithMultipart(File file, String s3Key) async {
  final uploadTask = Amplify.Storage.uploadFile(
    localFile: AWSFile.fromPath(file.path),
    key: s3Key,
    options: const StorageUploadFileOptions(
      accessLevel: StorageAccessLevel.private,
    ),
    onProgress: (progress) {
      final percentage = (progress.transferredBytes / progress.totalBytes) * 100;
      print('Upload progress: ${percentage.toStringAsFixed(1)}%');
    },
  );
  
  final result = await uploadTask.result;
  return result.uploadedItem.key;
}
```

2. **Handle Upload Interruptions:**
```dart
class ResumableUploadManager {
  final Map<String, UploadTask> _activeTasks = {};
  
  Future<String> uploadWithResume(String filePath, String s3Key) async {
    try {
      final task = Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(filePath),
        key: s3Key,
      );
      
      _activeTasks[s3Key] = task;
      
      final result = await task.result;
      _activeTasks.remove(s3Key);
      
      return result.uploadedItem.key;
      
    } catch (e) {
      _activeTasks.remove(s3Key);
      
      if (_isResumableError(e)) {
        // Retry upload
        return uploadWithResume(filePath, s3Key);
      }
      
      rethrow;
    }
  }
  
  void cancelUpload(String s3Key) {
    _activeTasks[s3Key]?.cancel();
    _activeTasks.remove(s3Key);
  }
}
```

#### Issue: File Download Failures

**Symptoms:**
- Downloads fail or timeout
- Corrupted downloaded files
- Access denied errors

**Solutions:**

1. **Verify File Integrity:**
```dart
Future<bool> verifyFileIntegrity(String s3Key, String localPath) async {
  try {
    // Get file metadata from S3
    final getPropertiesResult = await Amplify.Storage.getProperties(
      key: s3Key,
    ).result;
    
    final expectedSize = getPropertiesResult.storageItem.size;
    
    // Check local file size
    final localFile = File(localPath);
    final actualSize = await localFile.length();
    
    if (expectedSize != actualSize) {
      print('File size mismatch: expected $expectedSize, got $actualSize');
      return false;
    }
    
    // Verify checksum if available
    final metadata = getPropertiesResult.storageItem.metadata;
    if (metadata.containsKey('checksum')) {
      final expectedChecksum = metadata['checksum'];
      final actualChecksum = await _calculateChecksum(localFile);
      
      if (expectedChecksum != actualChecksum) {
        print('Checksum mismatch: expected $expectedChecksum, got $actualChecksum');
        return false;
      }
    }
    
    return true;
    
  } catch (e) {
    print('Integrity verification failed: $e');
    return false;
  }
}
```

2. **Implement Download Retry:**
```dart
Future<String> downloadFileWithRetry(String s3Key, String localPath) async {
  const maxRetries = 3;
  
  for (int attempt = 0; attempt < maxRetries; attempt++) {
    try {
      await Amplify.Storage.downloadFile(
        key: s3Key,
        localFile: AWSFile.fromPath(localPath),
      ).result;
      
      // Verify integrity
      if (await verifyFileIntegrity(s3Key, localPath)) {
        return localPath;
      } else {
        throw Exception('File integrity check failed');
      }
      
    } catch (e) {
      print('Download attempt ${attempt + 1} failed: $e');
      
      if (attempt < maxRetries - 1) {
        // Delete partial file
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
        
        // Wait before retry
        await Future.delayed(Duration(seconds: attempt + 1));
      } else {
        rethrow;
      }
    }
  }
  
  throw Exception('Download failed after $maxRetries attempts');
}
```

### 5. Network and Connectivity Issues

#### Issue: Intermittent Network Failures

**Symptoms:**
- Operations fail randomly
- Timeouts during sync
- Connection reset errors

**Solutions:**

1. **Network Status Monitoring:**
```dart
class NetworkMonitor {
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isOnline = true;
  
  void startMonitoring() {
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (!wasOnline && _isOnline) {
        // Connectivity restored
        _onConnectivityRestored();
      } else if (wasOnline && !_isOnline) {
        // Connectivity lost
        _onConnectivityLost();
      }
    });
  }
  
  void _onConnectivityRestored() {
    print('Connectivity restored, processing offline queue');
    _offlineSyncQueue.processQueue();
  }
  
  void _onConnectivityLost() {
    print('Connectivity lost, enabling offline mode');
    _cloudSyncService.enableOfflineMode();
  }
}
```

2. **Adaptive Timeout Configuration:**
```dart
class AdaptiveTimeoutManager {
  Duration _currentTimeout = Duration(seconds: 30);
  int _consecutiveFailures = 0;
  
  Duration getTimeout() {
    return _currentTimeout;
  }
  
  void recordSuccess() {
    _consecutiveFailures = 0;
    _currentTimeout = Duration(seconds: 30); // Reset to default
  }
  
  void recordFailure() {
    _consecutiveFailures++;
    
    // Increase timeout for poor connections
    if (_consecutiveFailures > 2) {
      _currentTimeout = Duration(
        seconds: math.min(120, 30 + (_consecutiveFailures * 10))
      );
    }
  }
}
```

### 6. Performance Issues

#### Issue: Slow Sync Operations

**Symptoms:**
- Long sync times
- UI freezing during sync
- High memory usage

**Solutions:**

1. **Optimize Query Performance:**
```dart
// Use pagination for large datasets
Future<List<Document>> fetchDocumentsPaginated({
  int limit = 50,
  String? nextToken,
}) async {
  final request = ModelQueries.list(
    Document.classType,
    limit: limit,
    nextToken: nextToken,
  );
  
  final response = await Amplify.API.query(request: request).response;
  return response.data?.items.whereType<Document>().toList() ?? [];
}

// Use selective field queries
Future<List<DocumentSummary>> fetchDocumentSummaries() async {
  const query = '''
    query ListDocumentSummaries {
      listDocuments {
        items {
          id
          title
          category
          lastModified
          syncState
        }
      }
    }
  ''';
  
  final request = GraphQLRequest<String>(
    document: query,
    apiName: 'householddocsapp',
  );
  
  final response = await Amplify.API.query(request: request).response;
  // Parse response and return summaries
}
```

2. **Implement Background Processing:**
```dart
class BackgroundSyncManager {
  final Isolate? _syncIsolate;
  
  Future<void> startBackgroundSync() async {
    final receivePort = ReceivePort();
    
    await Isolate.spawn(
      _backgroundSyncEntryPoint,
      receivePort.sendPort,
    );
    
    receivePort.listen((message) {
      if (message is SyncProgress) {
        _updateSyncProgress(message);
      } else if (message is SyncError) {
        _handleSyncError(message);
      }
    });
  }
  
  static void _backgroundSyncEntryPoint(SendPort sendPort) async {
    // Initialize Amplify in isolate
    await _initializeAmplify();
    
    // Perform sync operations
    try {
      final documents = await _fetchPendingDocuments();
      
      for (final doc in documents) {
        await _syncDocument(doc);
        sendPort.send(SyncProgress(
          completed: documents.indexOf(doc) + 1,
          total: documents.length,
        ));
      }
    } catch (e) {
      sendPort.send(SyncError(e.toString()));
    }
  }
}
```

## Diagnostic Tools

### 1. Amplify Logger Configuration

```dart
// Enable detailed logging
await Amplify.addPlugin(AmplifyAuthCognito(
  secureStorageFactory: AmplifySecureStorage.factoryFrom(
    macOSOptions: MacOSSecureStorageOptions(
      groupId: 'your.group.id',
    ),
  ),
));

// Configure log level
AmplifyLogger().logLevel = LogLevel.verbose;
```

### 2. Custom Diagnostic Tool

```dart
class SyncDiagnostics {
  Future<DiagnosticReport> runDiagnostics() async {
    final report = DiagnosticReport();
    
    // Test authentication
    report.authStatus = await _testAuthentication();
    
    // Test API connectivity
    report.apiStatus = await _testAPIConnectivity();
    
    // Test S3 connectivity
    report.s3Status = await _testS3Connectivity();
    
    // Check local database
    report.dbStatus = await _testLocalDatabase();
    
    // Check network connectivity
    report.networkStatus = await _testNetworkConnectivity();
    
    return report;
  }
  
  Future<TestResult> _testAuthentication() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      
      if (!session.isSignedIn) {
        return TestResult.failure('User not signed in');
      }
      
      final tokens = session.userPoolTokensResult.value;
      if (tokens.accessToken.expiresAt.isBefore(DateTime.now())) {
        return TestResult.warning('Access token expired');
      }
      
      return TestResult.success('Authentication OK');
      
    } catch (e) {
      return TestResult.failure('Auth test failed: $e');
    }
  }
  
  Future<TestResult> _testAPIConnectivity() async {
    try {
      // Simple query to test API
      final request = ModelQueries.list(Document.classType, limit: 1);
      await Amplify.API.query(request: request).response;
      
      return TestResult.success('API connectivity OK');
      
    } catch (e) {
      return TestResult.failure('API test failed: $e');
    }
  }
}

class DiagnosticReport {
  TestResult? authStatus;
  TestResult? apiStatus;
  TestResult? s3Status;
  TestResult? dbStatus;
  TestResult? networkStatus;
  
  bool get isHealthy => [
    authStatus,
    apiStatus,
    s3Status,
    dbStatus,
    networkStatus,
  ].every((status) => status?.isSuccess == true);
}

class TestResult {
  final bool isSuccess;
  final String message;
  final String? details;
  
  TestResult.success(this.message) : isSuccess = true, details = null;
  TestResult.failure(this.message, [this.details]) : isSuccess = false;
  TestResult.warning(this.message, [this.details]) : isSuccess = true;
}
```

### 3. Performance Profiler

```dart
class SyncProfiler {
  final Map<String, List<Duration>> _operationTimes = {};
  
  Future<T> profile<T>(String operation, Future<T> Function() task) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await task();
      stopwatch.stop();
      
      _recordTiming(operation, stopwatch.elapsed);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _recordTiming('$operation-error', stopwatch.elapsed);
      rethrow;
    }
  }
  
  void _recordTiming(String operation, Duration duration) {
    _operationTimes.putIfAbsent(operation, () => []).add(duration);
  }
  
  Map<String, PerformanceStats> getStats() {
    return _operationTimes.map((operation, times) {
      return MapEntry(operation, PerformanceStats.fromTimes(times));
    });
  }
}

class PerformanceStats {
  final Duration average;
  final Duration min;
  final Duration max;
  final int count;
  
  PerformanceStats({
    required this.average,
    required this.min,
    required this.max,
    required this.count,
  });
  
  factory PerformanceStats.fromTimes(List<Duration> times) {
    if (times.isEmpty) {
      return PerformanceStats(
        average: Duration.zero,
        min: Duration.zero,
        max: Duration.zero,
        count: 0,
      );
    }
    
    final totalMs = times.fold<int>(0, (sum, time) => sum + time.inMilliseconds);
    final avgMs = totalMs ~/ times.length;
    
    return PerformanceStats(
      average: Duration(milliseconds: avgMs),
      min: times.reduce((a, b) => a < b ? a : b),
      max: times.reduce((a, b) => a > b ? a : b),
      count: times.length,
    );
  }
}
```

## Emergency Procedures

### 1. Service Outage Response

```dart
class EmergencyProcedures {
  Future<void> handleServiceOutage() async {
    // 1. Enable offline mode
    await _enableOfflineMode();
    
    // 2. Notify users
    await _notifyUsersOfOutage();
    
    // 3. Queue all operations
    await _enableOperationQueuing();
    
    // 4. Monitor service recovery
    _startServiceMonitoring();
  }
  
  Future<void> _enableOfflineMode() async {
    await SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('offline_mode', true);
    });
    
    // Stop real-time sync
    await _realtimeSyncService.stopRealtimeSync();
    
    // Enable local-only operations
    _cloudSyncService.enableOfflineMode();
  }
}
```

### 2. Data Recovery Procedures

```dart
class DataRecoveryManager {
  Future<void> recoverFromCorruption() async {
    try {
      // 1. Backup current state
      await _backupCurrentState();
      
      // 2. Validate cloud data
      final cloudDocuments = await _fetchAllCloudDocuments();
      final validDocuments = await _validateDocuments(cloudDocuments);
      
      // 3. Restore from cloud
      await _restoreFromCloud(validDocuments);
      
      // 4. Verify integrity
      await _verifyDataIntegrity();
      
    } catch (e) {
      // Fallback to last known good backup
      await _restoreFromBackup();
    }
  }
}
```

## Monitoring and Alerting

### 1. Health Check Implementation

```dart
class HealthCheckService {
  Future<HealthStatus> checkHealth() async {
    final checks = await Future.wait([
      _checkAuthentication(),
      _checkAPIConnectivity(),
      _checkS3Access(),
      _checkDatabaseHealth(),
    ]);
    
    final failedChecks = checks.where((check) => !check.isHealthy).toList();
    
    return HealthStatus(
      isHealthy: failedChecks.isEmpty,
      checks: checks,
      timestamp: DateTime.now(),
    );
  }
  
  void startContinuousMonitoring() {
    Timer.periodic(Duration(minutes: 5), (_) async {
      final health = await checkHealth();
      
      if (!health.isHealthy) {
        await _alertOnHealthIssue(health);
      }
    });
  }
}
```

### 2. Error Rate Monitoring

```dart
class ErrorRateMonitor {
  final Map<String, int> _operationCounts = {};
  final Map<String, int> _errorCounts = {};
  
  void recordOperation(String operation, bool success) {
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
    
    if (!success) {
      _errorCounts[operation] = (_errorCounts[operation] ?? 0) + 1;
    }
    
    _checkErrorRate(operation);
  }
  
  void _checkErrorRate(String operation) {
    final total = _operationCounts[operation] ?? 0;
    final errors = _errorCounts[operation] ?? 0;
    
    if (total > 10) { // Minimum sample size
      final errorRate = errors / total;
      
      if (errorRate > 0.1) { // 10% error rate threshold
        _alertHighErrorRate(operation, errorRate);
      }
    }
  }
}
```

This troubleshooting guide provides comprehensive coverage of common AWS operation issues and their solutions. Use it as a reference when diagnosing and resolving sync-related problems in production.