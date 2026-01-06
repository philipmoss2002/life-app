# User Isolation Review - Multi-User Device Support

## Executive Summary

**Current Status**: ⚠️ **PARTIAL USER ISOLATION** - Some isolation exists but has critical gaps for multi-user scenarios.

**Risk Level**: 🔴 **HIGH** - Users could potentially access each other's documents and files.

## Data Structure Analysis

### 1. Remote Data Structure (AWS/Amplify)

#### ✅ **GOOD: DynamoDB (Document Metadata)**
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!
  userId: String!     # ✅ User isolation field
  title: String!
  category: String!
  filePaths: [String!]!
  # ... other fields
}
```
- **Amplify Auth Rules**: `@auth(rules: [{allow: owner}])` provides automatic user isolation
- **User ID Field**: `userId: String!` ensures documents are tied to specific users
- **Access Control**: Amplify automatically filters queries by authenticated user

#### ❌ **CRITICAL ISSUE: S3 Storage (Files)**
```dart
// Current S3 key structure
final s3Key = 'documents/$documentId/$timestamp-$fileName';
final publicPath = 'public/$s3Key';
```

**Problems:**
1. **No User ID in S3 Path**: Files are stored by document ID only, not user ID
2. **Public Access**: All files stored under `public/` prefix - accessible to all users
3. **Cross-User Access**: User A could potentially access User B's files if they know the document ID

**Recommended S3 Structure:**
```dart
// Should be:
final s3Key = 'documents/$userId/$documentId/$timestamp-$fileName';
final privatePath = 'private/$s3Key'; // Use private, not public
```

### 2. Local Data Structure (SQLite)

#### ✅ **GOOD: Database Schema**
```sql
CREATE TABLE documents (
  id INTEGER PRIMARY KEY,
  userId TEXT,           -- ✅ User isolation field
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  -- ... other fields
);
```

#### ✅ **GOOD: Query Filtering**
```dart
// Properly filters by user ID
final result = userId != null
  ? await db.query('documents', where: 'userId = ?', whereArgs: [userId])
  : await db.query('documents'); // ⚠️ Fallback gets ALL documents
```

#### ⚠️ **CONCERN: Fallback Behavior**
- When `userId` is null, queries return ALL documents from ALL users
- Could lead to data leakage if user ID is not properly set

## User Isolation Implementation Review

### ✅ **STRENGTHS**

#### 1. **Sign-Out Data Clearing**
```dart
Future<void> signOut() async {
  // Clear user-specific data from local database
  if (_currentUser != null) {
    await DatabaseService.instance.clearUserData(_currentUser!.id);
  }
  
  // Clear all user-specific data from singleton services
  await _clearAllUserData();
}
```

#### 2. **Comprehensive Service Cleanup**
```dart
Future<void> _clearAllUserData() async {
  // Clears data from:
  - SubscriptionService
  - AnalyticsService  
  - OfflineSyncQueueService
  - StorageManager
  - PerformanceMonitor
  - CloudSyncService
}
```

#### 3. **Database User Filtering**
```dart
Future<void> clearUserData(String userId) async {
  // Deletes only user-specific documents and file attachments
  await db.delete('documents', where: 'userId = ?', whereArgs: [userId]);
}
```

### ❌ **CRITICAL GAPS**

#### 1. **S3 File Access Control**
- **Issue**: Files stored under `public/` are accessible to all authenticated users
- **Risk**: User A could access User B's files by guessing document IDs
- **Impact**: Complete privacy breach

#### 2. **Document ID Predictability**
- **Issue**: Document IDs might be sequential or predictable
- **Risk**: Users could enumerate other users' documents
- **Impact**: Unauthorized access to metadata and files

#### 3. **Shared Preferences Isolation**
- **Issue**: Some settings might be stored globally in SharedPreferences
- **Risk**: User preferences could leak between accounts
- **Impact**: Privacy and UX issues

## Multi-User Device Scenarios

### Scenario 1: Sequential Users (Sign Out → Sign In)
**Current Status**: ✅ **MOSTLY SAFE**
- Sign-out properly clears local data
- New user gets clean state
- Remote data properly isolated by Amplify auth

### Scenario 2: Concurrent Users (App Backgrounded)
**Current Status**: ❌ **UNSAFE**
- If app is backgrounded during user switch, data might persist
- No session timeout or automatic sign-out
- Potential for data mixing

### Scenario 3: Malicious User Access
**Current Status**: ❌ **UNSAFE**
- User could potentially access files via direct S3 URLs
- Document IDs might be discoverable
- No audit trail for file access

## Recommendations

### 🔴 **CRITICAL (Must Fix)**

#### 1. **Fix S3 File Isolation**
```dart
// Current (UNSAFE)
final s3Key = 'documents/$documentId/$timestamp-$fileName';
final publicPath = 'public/$s3Key';

// Recommended (SAFE)
final s3Key = 'documents/$userId/$documentId/$timestamp-$fileName';
final privatePath = 'private/$s3Key';
```

#### 2. **Update Amplify Storage Configuration**
```dart
// Use private access level for user isolation
await Amplify.Storage.uploadFile(
  localFile: AWSFile.fromPath(file.path),
  path: StoragePath.fromString(privatePath), // private, not public
  options: const StorageUploadFileOptions(
    accessLevel: StorageAccessLevel.private, // Add this
  ),
);
```

#### 3. **Add User ID Validation**
```dart
// Ensure all document operations validate user ownership
Future<Document?> getDocument(String documentId, String userId) async {
  final doc = await _getDocumentById(documentId);
  if (doc?.userId != userId) {
    throw UnauthorizedAccessException('Document not owned by user');
  }
  return doc;
}
```

### 🟡 **HIGH PRIORITY (Should Fix)**

#### 4. **Add Session Timeout**
```dart
// Auto sign-out after inactivity
class SessionManager {
  static const Duration _sessionTimeout = Duration(minutes: 30);
  
  void startSessionTimer() {
    Timer.periodic(_sessionTimeout, (timer) {
      if (_isInactive()) {
        _authProvider.signOut();
      }
    });
  }
}
```

#### 5. **Enhance Document ID Security**
```dart
// Use UUIDs instead of sequential IDs
import 'package:uuid/uuid.dart';

final documentId = const Uuid().v4(); // Random UUID
```

#### 6. **Add Audit Logging**
```dart
// Track file access for security monitoring
await AuditService.logFileAccess(
  userId: currentUser.id,
  documentId: documentId,
  action: 'download',
  timestamp: DateTime.now(),
);
```

### 🟢 **MEDIUM PRIORITY (Nice to Have)**

#### 7. **Add Data Encryption**
```dart
// Encrypt sensitive data in local database
final encryptedTitle = await EncryptionService.encrypt(title, userKey);
```

#### 8. **Implement User Quotas**
```dart
// Prevent one user from consuming all storage
class UserQuotaManager {
  static const int maxDocumentsPerUser = 1000;
  static const int maxStoragePerUser = 5 * 1024 * 1024 * 1024; // 5GB
}
```

## Migration Plan

### Phase 1: Critical Security Fixes
1. **Update S3 key structure** to include user ID
2. **Change from public to private** storage access level
3. **Add user ownership validation** to all document operations
4. **Test multi-user scenarios** thoroughly

### Phase 2: Enhanced Security
1. **Implement session timeout**
2. **Add audit logging**
3. **Enhance document ID security**
4. **Add data validation layers**

### Phase 3: Advanced Features
1. **Add data encryption**
2. **Implement user quotas**
3. **Add admin monitoring tools**
4. **Performance optimizations**

## Testing Checklist

### Multi-User Device Testing
- [ ] User A signs in, creates documents, signs out
- [ ] User B signs in, cannot see User A's documents
- [ ] User B cannot access User A's files via direct URLs
- [ ] User A signs back in, sees only their documents
- [ ] App backgrounding/foregrounding doesn't mix user data
- [ ] Rapid user switching doesn't cause data leakage
- [ ] Network interruption during user switch is handled safely

## Conclusion

The current implementation has **good foundations** for user isolation but **critical security gaps** in file storage. The S3 public storage model is the biggest risk and must be addressed immediately for any multi-user deployment.

**Priority**: Fix S3 file isolation before any production deployment with multiple users.