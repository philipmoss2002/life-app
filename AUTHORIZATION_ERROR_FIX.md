# Authorization Error Fix

## Problem
Files are successfully uploading to S3, but DynamoDB records aren't being created due to GraphQL authorization errors:
- "Not authorized to access listDocuments on type Query"
- "Not Authorized to access createDocument on type Mutation"

## Root Cause
The GraphQL schema has been updated with proper `@auth` rules, but these changes haven't been deployed to AWS AppSync. The authorization rules need to be pushed to the backend to take effect.

## Schema Changes Made
Updated all models to use consistent owner-based authorization:

### Document Model
```graphql
type Document @model @auth(rules: [{allow: owner, ownerField: "userId", identityClaim: "sub"}]) {
  syncId: String! @primaryKey
  userId: String! @index(name: "byUserId", sortKeyFields: ["createdAt"])
  # ... other fields
}
```

### FileAttachment Model
```graphql
type FileAttachment @model @auth(rules: [
  {allow: owner, ownerField: "userId", identityClaim: "sub"},
  {allow: private, operations: [read]}
]) {
  id: ID!
  syncId: String! @index(name: "bySyncId", sortKeyFields: ["addedAt"])
  userId: String! @index(name: "byUserId", sortKeyFields: ["addedAt"])
  # ... other fields
}
```

### Other Models
- Device: Added `userId` field with proper authorization
- SyncEvent: Added `userId` field with proper authorization  
- Conflict: Added `userId` field with proper authorization
- DocumentTombstone, SyncState, UserSubscription, StorageUsage: Already had proper authorization

## Solution Steps

### 1. Deploy Updated Schema
```bash
cd household_docs_app
amplify push
```

When prompted:
- Select "Yes" to update resources
- Select "Yes" to generate code for your updated GraphQL API

**IMPORTANT**: This will regenerate model classes. You'll need to update application code to handle the new `userId` fields in FileAttachment, Device, SyncEvent, and Conflict models.

### 2. Update Application Code
After `amplify push`, you'll need to update code that creates these models to include the `userId` field:

#### FileAttachment Creation
```dart
// Before
final fileAttachment = FileAttachment(
  syncId: document.syncId,
  fileName: fileName,
  // ... other fields
);

// After
final fileAttachment = FileAttachment(
  syncId: document.syncId,
  userId: currentUser.id, // Add this
  fileName: fileName,
  // ... other fields
);
```

#### Device, SyncEvent, Conflict Creation
Similar updates needed wherever these models are created.

### 3. Verify Authorization Configuration
The authorization should work as follows:
- `ownerField: "userId"` - The field that contains the owner identifier
- `identityClaim: "sub"` - The JWT claim that contains the user identifier
- All models are created with `userId: currentUser.id` where `currentUser.id` is the Cognito `sub` claim

### 4. Test Document Operations
After deployment and code updates, test:
1. **Create Document**: Should succeed with proper userId
2. **List Documents**: Should only return documents owned by the authenticated user
3. **Update Document**: Should only allow updates to owned documents
4. **Delete Document**: Should only allow deletion of owned documents
5. **File Attachments**: Should inherit proper authorization from userId

### 5. Handle Migration
Existing records without `userId` fields will need to be migrated or may become inaccessible. Consider:
- Running a migration script to populate `userId` fields for existing records
- Or accepting that existing FileAttachments, Devices, etc. may need to be recreated

## Expected Behavior After Fix
- Documents will be created in DynamoDB with proper authorization
- Users will only see their own documents and related data
- All CRUD operations will respect owner-based access control
- S3 file uploads will continue to work as before

## Verification Commands
```bash
# Check Amplify status
amplify status

# View current GraphQL schema
amplify api gql-compile

# Test GraphQL operations (after deployment)
amplify console api
```

## Rollback Plan
If issues occur after deployment:
```bash
# Revert to previous version
amplify env checkout <previous-env>
# Or restore from backup
git checkout <previous-commit>
amplify push
```

## Notes
- The authorization fix requires backend deployment AND code updates
- Local schema changes don't affect authorization until pushed
- New `userId` fields must be populated in application code
- Consider data migration for existing records
- File attachments now have explicit user ownership rather than inheriting through relationships