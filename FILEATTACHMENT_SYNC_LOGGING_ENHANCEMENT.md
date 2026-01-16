# FileAttachment Sync Logging Enhancement

## Summary
Added comprehensive authentication and authorization logging to the FileAttachment sync manager to help debug why FileAttachment records are not being created in DynamoDB during remote sync.

## Problem Statement
During remote document sync:
- Document records are successfully created in DynamoDB
- Files are successfully uploaded to S3
- FileAttachment records are NOT being created in DynamoDB
- No errors are being logged in the current implementation

## Logging Enhancements Added

### 1. Authentication Details Logging
Added detailed logging to compare the FileAttachment's `userId` field with the authenticated user's credentials:

**Logged Information:**
- Current User ID from `Amplify.Auth.getCurrentUser()`
- User Sub Claim from `Amplify.Auth.fetchUserAttributes()`
- User Email from user attributes
- FileAttachment userId field
- Comparison results with clear MISMATCH warnings

### 2. Token Validation Logging
Added token-level validation to ensure proper authorization:

**Logged Information:**
- ID Token presence and validity
- Token userId field
- Comparison between token userId and FileAttachment userId
- Token access errors if any

### 3. GraphQL Mutation Variables Logging
Added comprehensive logging of all variables being sent to DynamoDB:

**Logged Variables:**
- `syncId` - FileAttachment's unique identifier
- `documentSyncId` - Reference to parent document (document link method only)
- `userId` - User identifier for authorization
- `fileName` - File name
- `label` - File label (nullable)
- `fileSize` - File size in bytes
- `s3Key` - S3 storage key
- `filePath` - Local file path
- `addedAt` - Timestamp
- `contentType` - MIME type (nullable)
- `checksum` - File checksum (nullable)
- `syncState` - Sync state
- `authorizationMode` - API authorization mode

### 4. Enhanced Error Detection
Added specific error detection for common authorization issues:

**Detection Points:**
- User ID mismatches between FileAttachment and authenticated user
- Token validation failures
- Missing or invalid authentication credentials
- GraphQL authorization mode verification

## Files Modified

### `lib/services/file_attachment_sync_manager.dart`
**Changes:**
1. Added `amplify_auth_cognito` import for `CognitoAuthSession` access
2. Enhanced `uploadFileAttachment()` method with authentication logging
3. Enhanced `_uploadFileAttachmentWithDocumentLink()` method with authentication logging
4. Added GraphQL variables logging for both upload methods
5. Added token validation and comparison logic

**New Logging Sections:**
- **Authentication Details**: Compares FileAttachment userId with authenticated user
- **Token Details**: Validates ID token and compares userId fields
- **GraphQL Variables**: Logs all mutation variables being sent to DynamoDB
- **Mismatch Detection**: Clear error messages for authorization mismatches

## Expected Debugging Benefits

### 1. Authorization Issue Detection
The logging will reveal if:
- FileAttachment `userId` doesn't match the authenticated user's sub claim
- Token validation is failing
- Wrong authorization mode is being used

### 2. Data Validation Issues
The logging will show if:
- Required fields are missing or null
- Field values are malformed
- GraphQL variables are incorrectly formatted

### 3. Timing Issues
The logging will help identify if:
- Authentication tokens are expired
- User session is invalid during FileAttachment sync
- Document-FileAttachment relationship timing issues

### 4. Silent Failure Detection
The enhanced logging will expose:
- Previously silent authorization failures
- GraphQL errors that were being caught and ignored
- Token refresh issues during sync operations

## Usage Instructions

### 1. Enable Debug Logging
Ensure the log service is configured to show INFO and ERROR level messages during FileAttachment sync operations.

### 2. Monitor Sync Operations
Watch for the following log patterns during document sync:

**Success Pattern:**
```
🔍 Fetching authenticated user details...
👤 Authentication Details:
   🆔 Current User ID: [user-id]
   🔑 User Sub Claim: [sub-claim]
   📄 FileAttachment userId: [user-id]
✅ FileAttachment userId matches authenticated user sub claim
🎫 Token Details:
   🔑 ID Token present: true
   👤 Token userId: [user-id]
✅ ID Token userId matches FileAttachment userId
📋 GraphQL Mutation Variables:
   [all variables logged]
```

**Failure Pattern:**
```
❌ MISMATCH: FileAttachment userId does not match authenticated user sub claim
   Expected (sub claim): [expected-id]
   Actual (FileAttachment): [actual-id]
   This may cause authorization failures in DynamoDB
```

### 3. Analyze Results
Based on the logs, identify:
- **Authorization Mismatches**: Look for MISMATCH error messages
- **Token Issues**: Look for token validation failures
- **Missing Data**: Check if any GraphQL variables are null/empty
- **Timing Problems**: Check if authentication details change between Document and FileAttachment sync

## Next Steps

1. **Test Document Sync**: Create a document with file attachments and monitor the logs
2. **Identify Root Cause**: Use the detailed logs to pinpoint the exact failure reason
3. **Implement Fix**: Based on findings, implement appropriate fixes:
   - Fix userId assignment if there's a mismatch
   - Fix token refresh if tokens are invalid
   - Fix timing if there are race conditions
   - Fix authorization rules if GraphQL permissions are wrong

## Technical Notes

- Logging is non-blocking and won't affect sync performance
- Token access uses proper Amplify API methods (`CognitoAuthSession.userPoolTokensResult.value`)
- All sensitive data (tokens, user IDs) are logged for debugging but should be filtered in production
- Error handling ensures that logging failures don't break the sync process

This enhancement provides comprehensive visibility into the FileAttachment sync process, making it much easier to identify and fix the root cause of the DynamoDB record creation failures.