# S3 Access Denied Error - Root Cause Analysis

## Issue Summary

**Problem**: Getting S3 access denied errors from both PersistentFileService and SimpleFileSyncManager when syncing new documents.

**Status**: ❌ CRITICAL - Blocking file uploads and downloads

**Impact**: Users cannot upload or download files, breaking core functionality

## Root Cause Identified

### Primary Issue: Amplify Configuration Mismatch

**Location**: `lib/amplifyconfiguration.dart` line 92

**Current Configuration**:
```dart
"storage": {
    "plugins": {
        "awsS3StoragePlugin": {
            "bucket": "householddocsapp9f4f55b3c6c94dc9a01229ca901e4863e624-dev",
            "region": "eu-west-2",
            "defaultAccessLevel": "guest"  // ❌ WRONG!
        }
    }
}
```

**Expected Configuration**:
```dart
"storage": {
    "plugins": {
        "awsS3StoragePlugin": {
            "bucket": "householddocsapp9f4f55b3c6c94dc9a01229ca901e4863e624-dev",
            "region": "eu-west-2",
            "defaultAccessLevel": "private"  // ✅ CORRECT
        }
    }
}
```

## Technical Analysis

### Why This Causes Access Denied

1. **Code Expects Private Access**:
   - PersistentFileService generates paths like: `private/{userSub}/documents/{syncId}/{fileName}`
   - SimpleFileSyncManager uses PersistentFileService for all operations
   - Both services expect S3 private access level with User Pool authentication

2. **Configuration Says Guest Access**:
   - `defaultAccessLevel: "guest"` tells Amplify to use unauthenticated access
   - Guest access doesn't have permissions to write to `private/` prefix paths
   - Guest access can't access user-specific folders

3. **The Mismatch**:
   ```
   Code generates:     private/{userSub}/documents/...
   Amplify tries:      guest access (unauthenticated)
   S3 Policy says:     "Access Denied - guest can't access private/"
   ```

### Path Analysis

**PersistentFileService Upload Flow**:
```dart
// 1. Generate S3 path with private prefix
final s3Key = await generateS3Path(syncId, fileName);
// Returns: "private/12345678-1234-1234-1234-123456789012/documents/sync_abc/file.pdf"

// 2. Upload using Amplify Storage
await Amplify.Storage.uploadFile(
  localFile: AWSFile.fromPath(filePath),
  path: StoragePath.fromString(s3Key),  // Uses "private/" prefix
).result;

// 3. Amplify sees defaultAccessLevel: "guest"
// 4. Tries to upload as unauthenticated user
// 5. S3 rejects: "Access Denied"
```

**SimpleFileSyncManager Upload Flow**:
```dart
// 1. Delegates to PersistentFileService
final s3Key = await _persistentFileService.uploadFile(filePath, syncId);

// 2. Same issue as above - uses private prefix with guest access
```

### AWS S3 Access Levels Explained

| Access Level | Path Prefix | Authentication | Use Case |
|-------------|-------------|----------------|----------|
| **guest** | `public/` | None required | Public files accessible to anyone |
| **protected** | `protected/{identityId}/` | Read: Any authenticated user<br>Write: Owner only | Shared files with read access |
| **private** | `private/{identityId}/` | Read/Write: Owner only | User-specific private files |

**Current Setup**:
- Configuration: `guest` (unauthenticated)
- Code uses: `private/` prefix (requires authentication)
- Result: ❌ Access Denied

**Required Setup**:
- Configuration: `private` (authenticated)
- Code uses: `private/` prefix (requires authentication)
- Result: ✅ Access Granted

## Evidence from Code

### 1. PersistentFileService Path Generation
```dart
// lib/services/persistent_file_service.dart
Future<String> generateS3Path(String syncId, String fileName) async {
  final filePath = await generateFilePath(syncId, fileName);
  return filePath.s3Key;  // Returns "private/{userSub}/documents/..."
}
```

### 2. FilePath Model
```dart
// lib/models/file_path.dart
class FilePath {
  String get s3Key => 'private/$userSub/documents/$syncId/$fileName';
  // Always uses "private/" prefix
}
```

### 3. Amplify Configuration
```dart
// lib/amplifyconfiguration.dart
"defaultAccessLevel": "guest"  // ❌ Conflicts with private/ prefix
```

### 4. Expected Configuration (from design docs)
```dart
// lib/config/amplify_config.dart (template)
'defaultAccessLevel': 'private',  // ✅ Matches code expectations
```

## Impact Assessment

### Affected Operations

1. **File Uploads** ❌
   - PersistentFileService.uploadFile() → Access Denied
   - SimpleFileSyncManager.uploadFile() → Access Denied
   - All document syncing fails

2. **File Downloads** ❌
   - PersistentFileService.downloadFile() → Access Denied
   - SimpleFileSyncManager.downloadFile() → Access Denied
   - Users can't retrieve their files

3. **File Deletions** ❌
   - PersistentFileService.deleteFile() → Access Denied
   - SimpleFileSyncManager.deleteFile() → Access Denied
   - File cleanup fails

4. **File Listing** ❌
   - StorageManager._listUserS3Files() → Access Denied
   - Can't enumerate user files

### User Impact

- **New Documents**: Cannot be uploaded
- **Existing Documents**: Cannot be downloaded or deleted
- **File Sync**: Completely broken
- **User Experience**: App appears non-functional for file operations

## Proposed Fix

### Solution: Update Amplify Configuration

**File**: `lib/amplifyconfiguration.dart`

**Change Required**:
```dart
// BEFORE (line 92)
"defaultAccessLevel": "guest"

// AFTER
"defaultAccessLevel": "private"
```

### Why This Fixes The Issue

1. **Alignment**: Configuration matches code expectations
2. **Authentication**: Amplify will use authenticated user credentials
3. **Authorization**: S3 will allow access to `private/{userSub}/` paths
4. **User Isolation**: Each user can only access their own files

### Implementation Steps

1. **Update Configuration**:
   ```dart
   // lib/amplifyconfiguration.dart
   "storage": {
       "plugins": {
           "awsS3StoragePlugin": {
               "bucket": "householddocsapp9f4f55b3c6c94dc9a01229ca901e4863e624-dev",
               "region": "eu-west-2",
               "defaultAccessLevel": "private"  // ✅ CHANGE THIS
           }
       }
   }
   ```

2. **Verify User Authentication**:
   - Ensure users are authenticated before file operations
   - PersistentFileService already validates this
   - No code changes needed

3. **Test File Operations**:
   - Upload a new document
   - Download an existing document
   - Delete a document
   - Verify all operations succeed

### Alternative Considerations

**Option 1: Change Path Prefix (NOT RECOMMENDED)**
- Change code to use `public/` prefix instead of `private/`
- ❌ Breaks security - all files become public
- ❌ Violates design requirements
- ❌ Breaks User Pool sub isolation

**Option 2: Use Protected Access (NOT RECOMMENDED)**
- Change to `protected/` prefix
- ❌ Allows other authenticated users to read files
- ❌ Violates privacy requirements
- ❌ Not aligned with design

**Option 3: Fix Configuration (RECOMMENDED)**
- Change `defaultAccessLevel` to `"private"`
- ✅ Aligns with code expectations
- ✅ Maintains security and privacy
- ✅ Follows AWS best practices
- ✅ Matches design requirements

## Verification Steps

### After Applying Fix

1. **Check Configuration**:
   ```bash
   grep -A 5 "defaultAccessLevel" lib/amplifyconfiguration.dart
   # Should show: "defaultAccessLevel": "private"
   ```

2. **Test Upload**:
   ```dart
   final service = PersistentFileService();
   final s3Key = await service.uploadFile('/path/to/file.pdf', 'test-sync-id');
   // Should succeed without Access Denied error
   ```

3. **Test Download**:
   ```dart
   final localPath = await service.downloadFile(s3Key, 'test-sync-id');
   // Should succeed and return local file path
   ```

4. **Verify S3 Path**:
   ```dart
   print(s3Key);
   // Should print: private/{userSub}/documents/test-sync-id/file.pdf
   ```

5. **Check Logs**:
   ```
   ✅ File uploaded successfully: private/...
   ✅ File downloaded successfully to: /tmp/...
   ```

### Expected Behavior After Fix

- ✅ File uploads succeed
- ✅ File downloads succeed
- ✅ File deletions succeed
- ✅ User isolation maintained
- ✅ No Access Denied errors
- ✅ All file operations use User Pool sub-based paths

## Additional Considerations

### AWS IAM Policy

Verify that the Cognito Identity Pool has the correct IAM policy for private access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME/private/${cognito-identity.amazonaws.com:sub}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET_NAME"
      ],
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "private/${cognito-identity.amazonaws.com:sub}/*"
          ]
        }
      }
    }
  ]
}
```

**Note**: The `${cognito-identity.amazonaws.com:sub}` variable is automatically replaced by AWS with the User Pool sub at runtime.

### Amplify CLI Configuration

If using Amplify CLI, ensure the storage configuration is correct:

```bash
amplify update storage
# Select: Content (Images, audio, video, etc.)
# Default access: Private (Authenticated users only)
```

Then regenerate the configuration:
```bash
amplify push
```

## Prevention

### Future Configuration Changes

1. **Document Configuration**:
   - Add comments in amplifyconfiguration.dart explaining the access level
   - Reference this analysis document

2. **Validation**:
   - Add a startup check to verify configuration matches code expectations
   - Log warning if mismatch detected

3. **Testing**:
   - Include configuration validation in integration tests
   - Test file operations in CI/CD pipeline

### Recommended Code Addition

Add configuration validation to PersistentFileService:

```dart
Future<void> validateConfiguration() async {
  // Check if Amplify is configured with private access
  // Log warning if configuration mismatch detected
  _logWarning('⚠️ Verify defaultAccessLevel is set to "private" in amplifyconfiguration.dart');
}
```

## Summary

**Root Cause**: Configuration mismatch between code expectations (`private` access) and Amplify configuration (`guest` access)

**Fix**: Change `defaultAccessLevel` from `"guest"` to `"private"` in `lib/amplifyconfiguration.dart`

**Impact**: Critical - blocks all file operations

**Effort**: Minimal - single line change

**Risk**: Low - aligns configuration with design and code

**Testing**: Required - verify all file operations after change

**Priority**: 🔴 CRITICAL - Fix immediately

---

## Next Steps

1. ✅ Review this analysis
2. ⏳ Update `lib/amplifyconfiguration.dart`
3. ⏳ Test file upload
4. ⏳ Test file download
5. ⏳ Test file deletion
6. ⏳ Verify no Access Denied errors
7. ⏳ Deploy to production

**Estimated Fix Time**: 5 minutes
**Estimated Test Time**: 15 minutes
**Total Time to Resolution**: 20 minutes
