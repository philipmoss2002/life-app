# S3 Access Denied - Root Cause Analysis and Proposed Fix

## Date: January 16, 2026
## Status: 🔴 CRITICAL ISSUE IDENTIFIED

---

## Executive Summary

The S3 access denied errors persist despite changing `defaultAccessLevel` to `"private"` because of a **fundamental mismatch between the code's path structure and AWS IAM policy expectations**.

### The Core Problem

**Your code generates paths like:**
```
private/{userPoolSub}/documents/{syncId}/{fileName}
```

**But AWS IAM policies expect:**
```
private/{identityPoolId}/*
```

**These are DIFFERENT identifiers:**
- **User Pool Sub**: JWT token claim (e.g., `abc123-def456-ghi789`)
- **Identity Pool ID**: AWS Cognito Identity ID (e.g., `eu-west-2:12345678-1234-1234-1234-123456789012`)

---

## Detailed Analysis

### 1. What the Code Does

In `PersistentFileService.getUserPoolSub()`:
```dart
// Get current authenticated user
final user = await Amplify.Auth.getCurrentUser();

// The userId is the User Pool sub (persistent identifier)
final userPoolSub = user.userId;
```

This retrieves the **User Pool sub** from the JWT token.

Then in `FilePath.create()`:
```dart
final filePath = FilePath.create(
  userSub: userPoolSub,  // ← User Pool sub
  syncId: syncId,
  fileName: fileName,
);
// Generates: private/{userPoolSub}/documents/{syncId}/{fileName}
```

### 2. What AWS IAM Policies Expect

From `cloudformation-template.json`:
```json
{
  "Effect": "Allow",
  "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
  "Resource": [
    "arn:aws:s3:::BUCKET_NAME/private/${cognito-identity.amazonaws.com:sub}/*"
  ]
}
```

The IAM policy variable `${cognito-identity.amazonaws.com:sub}` resolves to the **Identity Pool ID**, NOT the User Pool sub.

### 3. Why This Causes Access Denied

When you upload a file:

1. **Code generates path**: `private/abc123-def456-ghi789/documents/sync_123/file.pdf`
   - Uses User Pool sub: `abc123-def456-ghi789`

2. **IAM policy allows**: `private/eu-west-2:12345678-1234-1234-1234-123456789012/*`
   - Expects Identity Pool ID: `eu-west-2:12345678-1234-1234-1234-123456789012`

3. **Result**: Path mismatch → Access Denied

---

## The Two Identifiers Explained

### User Pool Sub (What You're Using)
- **Source**: Cognito User Pool JWT token
- **Format**: UUID-like string (e.g., `abc123-def456-ghi789`)
- **Persistence**: Tied to user account, survives app reinstalls
- **Retrieved via**: `Amplify.Auth.getCurrentUser().userId`
- **Use case**: Application-level user identification

### Identity Pool ID (What IAM Expects)
- **Source**: Cognito Identity Pool federated identity
- **Format**: Region + UUID (e.g., `eu-west-2:12345678-1234-1234-1234-123456789012`)
- **Persistence**: Tied to AWS credentials, survives app reinstalls
- **Retrieved via**: `Amplify.Auth.fetchAuthSession().identityId`
- **Use case**: AWS service authorization (S3, DynamoDB, etc.)

---

## Why Your Previous Fix Didn't Work

Changing `defaultAccessLevel` from `"guest"` to `"private"` was correct, but insufficient:

✅ **What it fixed**: Told Amplify to use private access level
❌ **What it didn't fix**: The path structure mismatch

The configuration change ensures Amplify uses authenticated credentials, but the IAM policy still expects paths with Identity Pool IDs, not User Pool subs.

---

## Proposed Solution

### Option 1: Use Identity Pool ID (RECOMMENDED)

**Change the code to use Identity Pool ID instead of User Pool sub.**

#### Advantages:
- ✅ Aligns with AWS IAM policy expectations
- ✅ No backend/IAM policy changes needed
- ✅ Follows AWS best practices
- ✅ Works with existing Amplify configuration
- ✅ Maintains user isolation

#### Changes Required:

**1. Update `PersistentFileService.getUserPoolSub()` method:**

```dart
/// Get the persistent Identity Pool ID for the current authenticated user
/// This identifier is used by AWS IAM policies for S3 access control
Future<String> getIdentityPoolId() async {
  _logInfo('🔑 PersistentFileService: Retrieving Identity Pool ID');

  try {
    // Check cache first
    if (_cachedIdentityPoolId != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration) {
      _logInfo('✅ Using cached Identity Pool ID');
      return _cachedIdentityPoolId!;
    }

    // Get auth session which contains Identity Pool ID
    final session = await Amplify.Auth.fetchAuthSession();
    
    // Extract Identity Pool ID
    final identityId = session.identityId;
    
    if (identityId == null || identityId.isEmpty) {
      throw UserPoolSubException(
          'Identity Pool ID is null or empty - user may not be properly authenticated');
    }

    // Validate Identity Pool ID format (should be region:uuid)
    if (!identityId.contains(':')) {
      throw UserPoolSubException(
          'Invalid Identity Pool ID format: $identityId');
    }

    // Cache the validated Identity Pool ID
    _cachedIdentityPoolId = identityId;
    _cacheTimestamp = DateTime.now();

    _logInfo('✅ Retrieved Identity Pool ID: ${identityId.substring(0, 15)}...');
    return identityId;
  } catch (e) {
    _logError('❌ PersistentFileService getIdentityPoolId failed: $e');
    throw FileOperationErrorHandler.handleError(
        e is Exception ? e : Exception(e.toString()));
  }
}
```

**2. Update all calls from `getUserPoolSub()` to `getIdentityPoolId()`:**

- In `generateFilePath()`
- In `generateS3Path()`
- In `generateS3DirectoryPath()`
- In `validateS3KeyOwnership()`
- In all migration methods

**3. Update `FilePath` model:**

Rename `userSub` parameter to `identityId` for clarity:

```dart
final filePath = FilePath.create(
  userSub: identityId,  // Now using Identity Pool ID
  syncId: syncId,
  fileName: fileName,
);
```

Or better, update the model to use `identityId` as the parameter name.

**4. Update path format documentation:**

Change from:
```
private/{userPoolSub}/documents/{syncId}/{fileName}
```

To:
```
private/{identityPoolId}/documents/{syncId}/{fileName}
```

#### Migration Strategy:

Since you already have files stored with User Pool sub paths, you'll need to:

1. **Detect legacy files**: Files with User Pool sub in path
2. **Migrate to new paths**: Copy files to Identity Pool ID paths
3. **Update database references**: Update any stored S3 keys
4. **Clean up old files**: Delete legacy files after successful migration

---

### Option 2: Custom IAM Policy (NOT RECOMMENDED)

**Modify AWS IAM policies to accept User Pool sub paths.**

#### Disadvantages:
- ❌ Requires manual AWS IAM policy changes
- ❌ Goes against AWS best practices
- ❌ More complex to maintain
- ❌ Requires CloudFormation template modifications
- ❌ May break on Amplify updates

#### Changes Required:

Would need to modify the CloudFormation template to add a custom IAM policy that allows paths with User Pool sub:

```json
{
  "Effect": "Allow",
  "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
  "Resource": [
    "arn:aws:s3:::BUCKET_NAME/private/*"
  ],
  "Condition": {
    "StringLike": {
      "s3:prefix": "private/${cognito-identity.amazonaws.com:sub}/*"
    }
  }
}
```

This is complex and fragile.

---

### Option 3: Use Protected Access Level

**Switch from `private` to `protected` access level.**

#### How it works:
- `protected` access level uses Identity Pool ID automatically
- Path format: `protected/{identityPoolId}/{fileName}`
- IAM policies already configured for this

#### Advantages:
- ✅ Simpler path structure
- ✅ Works with existing IAM policies
- ✅ No custom code needed

#### Disadvantages:
- ❌ Less flexible path structure (no custom subdirectories)
- ❌ Can't organize by `documents/{syncId}/`
- ❌ Other users can read your files (but not write)

---

## Recommended Solution: Option 1

**Use Identity Pool ID instead of User Pool sub.**

### Why This is Best:

1. **Aligns with AWS**: IAM policies expect Identity Pool ID
2. **No backend changes**: Works with existing Amplify configuration
3. **Maintains flexibility**: Can still use custom path structure
4. **Follows best practices**: Uses AWS-recommended approach
5. **User isolation**: Identity Pool ID is unique per user
6. **Persistence**: Identity Pool ID survives app reinstalls

### Implementation Steps:

1. ✅ **Rename method**: `getUserPoolSub()` → `getIdentityPoolId()`
2. ✅ **Update retrieval**: Use `fetchAuthSession().identityId`
3. ✅ **Update all callers**: Change all references
4. ✅ **Update validation**: Validate Identity Pool ID format
5. ✅ **Update documentation**: Reflect new path structure
6. ✅ **Test thoroughly**: Verify upload/download/delete work
7. ✅ **Migrate existing files**: Move User Pool sub files to Identity Pool ID paths

---

## Testing the Fix

After implementing Option 1:

### 1. Verify Identity Pool ID Retrieval
```dart
final identityId = await persistentFileService.getIdentityPoolId();
print('Identity Pool ID: $identityId');
// Expected: eu-west-2:12345678-1234-1234-1234-123456789012
```

### 2. Verify Path Generation
```dart
final s3Key = await persistentFileService.generateS3Path('sync_123', 'test.pdf');
print('S3 Key: $s3Key');
// Expected: private/eu-west-2:12345678-1234-1234-1234-123456789012/documents/sync_123/test.pdf
```

### 3. Test File Upload
```dart
final s3Key = await persistentFileService.uploadFile('/path/to/file.pdf', 'sync_123');
print('Upload successful: $s3Key');
// Expected: Success, no Access Denied
```

### 4. Verify IAM Policy Match
The generated path should now match what IAM policies expect:
- **Generated**: `private/eu-west-2:12345678.../documents/sync_123/file.pdf`
- **IAM allows**: `private/${cognito-identity.amazonaws.com:sub}/*`
- **Match**: ✅ YES

---

## Impact Assessment

### Code Changes:
- **Files to modify**: ~10 files
- **Methods to update**: ~15 methods
- **Test files to update**: ~20 test files
- **Estimated effort**: 4-6 hours

### Migration Impact:
- **Existing files**: Need migration to new paths
- **Database updates**: Update stored S3 keys
- **User impact**: Transparent (handled automatically)
- **Rollback**: Possible (keep old files until migration confirmed)

### Risk Level: 🟡 MEDIUM
- Code changes are straightforward
- Migration adds complexity
- Thorough testing required
- Rollback plan needed

---

## Alternative Quick Fix (Temporary)

If you need immediate functionality while planning the full fix:

### Use Amplify's Built-in Path Handling

Instead of manually constructing paths, let Amplify handle it:

```dart
// Upload with automatic path handling
final uploadResult = await Amplify.Storage.uploadFile(
  localFile: AWSFile.fromPath(filePath),
  path: StoragePath.fromIdentityId(
    (identityId) => 'documents/$syncId/$fileName',
  ),
).result;
```

This uses `StoragePath.fromIdentityId()` which automatically:
- Retrieves the Identity Pool ID
- Constructs the correct path
- Matches IAM policy expectations

---

## Summary

### Root Cause:
Path structure mismatch between code (User Pool sub) and IAM policies (Identity Pool ID)

### Recommended Fix:
Switch from User Pool sub to Identity Pool ID in all file operations

### Why It Will Work:
Identity Pool ID matches what AWS IAM policies expect for `private/` access

### Next Steps:
1. Review this analysis
2. Approve Option 1 (Identity Pool ID approach)
3. Implement the code changes
4. Test thoroughly
5. Plan and execute file migration
6. Deploy to production

---

**Analysis By**: Kiro AI Assistant  
**Date**: January 16, 2026  
**Priority**: 🔴 CRITICAL  
**Confidence**: 🟢 HIGH (95%)
