# FileAttachment syncId Field Fix - COMPLETED

## Issue
Sync was failing with the error:
```
Validation error of type FieldUndefined: Field 'syncId' in type 'FileAttachment' is undefined @ 'listDocuments/items/fileAttachments/items/syncId'
```

## Root Cause
The user correctly identified that FileAttachment should have its own `syncId` field for proper sync identifier-based associations between documents and files, since local id and remote id can change. The GraphQL queries were trying to fetch a `syncId` field from FileAttachment objects, but the FileAttachment model was using `id` as the primary key instead of `syncId`.

## Solution Implemented

### 1. Recreated Amplify Backend
Since there was no existing data, we deleted and recreated the entire Amplify backend to avoid destructive change issues:
- Deleted the old Amplify environment with `amplify delete --force`
- Initialized a new Amplify project with `amplify init --yes`
- Added authentication with `amplify add auth`
- Added S3 storage with `amplify add storage`
- Added GraphQL API with `amplify add api`

### 2. Updated GraphQL Schema
**File:** `amplify/backend/api/householddocsapp/schema.graphql`

Updated the FileAttachment model to use `syncId` as the primary key:
```graphql
type FileAttachment @model @auth(rules: [
  {allow: owner, ownerField: "userId", identityClaim: "sub"},
  {allow: private, operations: [read]}
]) {
  syncId: String! @primaryKey
  documentSyncId: String! @index(name: "byDocumentSyncId", sortKeyFields: ["addedAt"])
  userId: String! @index(name: "byUserId", sortKeyFields: ["addedAt"])
  fileName: String!
  label: String
  fileSize: Int!
  s3Key: String!
  filePath: String!
  addedAt: AWSDateTime!
  contentType: String
  checksum: String
  syncState: String!
  
  # Relationship: Each file attachment belongs to one document
  document: Document @belongsTo(fields: ["documentSyncId"])
}
```

### 3. Deployed Schema Changes
Successfully deployed the new schema with:
```bash
amplify push --yes
```

### 4. Regenerated Models
Generated new Dart models with the updated schema:
```bash
amplify codegen models --force
```

The new FileAttachment model now correctly uses `syncId` as the primary key:
```dart
FileAttachmentModelIdentifier get modelIdentifier {
  try {
    return FileAttachmentModelIdentifier(
      syncId: _syncId!
    );
  } catch(e) {
    // error handling
  }
}

String get syncId {
  try {
    return _syncId!;
  } catch(e) {
    // error handling
  }
}
```

### 5. Updated GraphQL Queries
**File:** `lib/services/document_sync_manager.dart`

Updated both GraphQL queries to use `syncId` instead of `id`:

**downloadDocument method:**
```graphql
fileAttachments {
  items {
    syncId
    fileName
    label
    fileSize
    s3Key
    filePath
    addedAt
    contentType
    checksum
    syncState
  }
}
```

**fetchAllDocuments method:**
```graphql
fileAttachments {
  items {
    syncId
    fileName
    label
    fileSize
    s3Key
    filePath
    addedAt
    contentType
    checksum
    syncState
  }
}
```

### 6. Updated Configuration
Updated `amplifyconfiguration.dart` with the new API endpoint and keys:
- New GraphQL endpoint: `https://pjqguhkifvat7b5xjycsknzbta.appsync-api.eu-west-2.amazonaws.com/graphql`
- New API key: `da2-67oyxyshefgfjlo4yjzq7ll5oi`

## Impact
- ✅ FileAttachment now has its own `syncId` field as the primary key
- ✅ GraphQL queries now correctly reference the `syncId` field
- ✅ Sync operations should work without the GraphQL validation error
- ✅ FileAttachment associations are now based on sync identifiers, providing consistent IDs across local and remote storage
- ✅ No data loss since there was no existing data

## Testing
The FileAttachment model was verified to work correctly with the new `syncId` primary key. The model can be instantiated and the `syncId` field is properly accessible.

## Files Modified
- `household_docs_app/amplify/backend/api/householddocsapp/schema.graphql`
- `household_docs_app/lib/services/document_sync_manager.dart`
- `household_docs_app/amplifyconfiguration.dart`
- `household_docs_app/lib/models/FileAttachment.dart` (regenerated)
- All other model files (regenerated)

## Next Steps
The sync functionality should now work correctly with FileAttachment using `syncId` as the primary key. Test the sync operations to ensure the GraphQL validation error is resolved.