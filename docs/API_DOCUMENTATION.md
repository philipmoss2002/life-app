# Cloud Sync API Documentation

## Overview

This document provides comprehensive documentation for the Household Docs App cloud synchronization API. The API is built on AWS Amplify with GraphQL for data operations and S3 for file storage.

## GraphQL Schema

### Document Type

The `Document` type represents a household document with metadata and file attachments.

```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!
  userId: String! @index(name: "byUserId")
  title: String!
  category: String!
  filePaths: [String!]!
  renewalDate: AWSDateTime
  notes: String
  createdAt: AWSDateTime!
  lastModified: AWSDateTime!
  version: Int!
  syncState: String!
  conflictId: String
  deleted: Boolean
  deletedAt: AWSDateTime
  fileAttachments: [FileAttachment] @hasMany(indexName: "byDocumentId", fields: ["id"])
}
```

**Fields:**
- `id`: Unique identifier for the document
- `userId`: Owner's user ID (automatically set by Cognito)
- `title`: Document title (required)
- `category`: Document category (required)
- `filePaths`: Array of local file paths
- `renewalDate`: Optional renewal date for documents like insurance
- `notes`: Optional notes about the document
- `createdAt`: Document creation timestamp
- `lastModified`: Last modification timestamp
- `version`: Version number for conflict detection
- `syncState`: Current sync status (notSynced, syncing, synced, error)
- `conflictId`: ID for conflict resolution
- `deleted`: Soft delete flag
- `deletedAt`: Deletion timestamp
- `fileAttachments`: Related file attachments

### FileAttachment Type

The `FileAttachment` type represents files attached to documents.

```graphql
type FileAttachment @model @auth(rules: [{allow: owner}]) {
  id: ID!
  documentId: ID! @index(name: "byDocumentId", sortKeyFields: ["addedAt"])
  filePath: String!
  fileName: String!
  label: String
  fileSize: Int!
  s3Key: String!
  addedAt: AWSDateTime!
  syncState: String!
  document: Document @belongsTo(fields: ["documentId"])
}
```

**Fields:**
- `id`: Unique identifier for the file attachment
- `documentId`: ID of the parent document
- `filePath`: Local file path
- `fileName`: Original file name
- `label`: Optional user-defined label
- `fileSize`: File size in bytes
- `s3Key`: S3 storage key
- `addedAt`: Timestamp when file was added
- `syncState`: Current sync status
- `document`: Parent document relationship

### Device Type

The `Device` type tracks devices connected to a user account.

```graphql
type Device @model @auth(rules: [{allow: owner}]) {
  id: ID!
  deviceName: String!
  deviceType: String!
  lastSyncTime: AWSDateTime!
  isActive: Boolean!
  createdAt: AWSDateTime!
}
```

### SyncEvent Type

The `SyncEvent` type tracks sync events for monitoring and debugging.

```graphql
type SyncEvent @model @auth(rules: [{allow: owner}]) {
  id: ID!
  eventType: String!
  entityType: String!
  entityId: String!
  message: String
  timestamp: AWSDateTime!
  deviceId: String
}
```

### SyncState Type

The `SyncState` type tracks overall sync state for a user.

```graphql
type SyncState @model @auth(rules: [{allow: owner}]) {
  id: ID!
  userId: String! @index(name: "byUserId")
  lastSyncTime: AWSDateTime!
  pendingOperations: Int!
  conflictCount: Int!
  errorCount: Int!
}
```

## API Operations

### Document Operations

#### Create Document

**Mutation:**
```graphql
mutation CreateDocument($input: CreateDocumentInput!) {
  createDocument(input: $input) {
    id
    userId
    title
    category
    filePaths
    renewalDate
    notes
    createdAt
    lastModified
    version
    syncState
  }
}
```

**Input:**
```json
{
  "input": {
    "title": "Insurance Policy",
    "category": "Insurance",
    "filePaths": ["/path/to/file1.pdf"],
    "renewalDate": "2024-12-31T00:00:00Z",
    "notes": "Annual renewal required",
    "version": 1,
    "syncState": "syncing"
  }
}
```

#### Update Document

**Mutation:**
```graphql
mutation UpdateDocument($input: UpdateDocumentInput!) {
  updateDocument(input: $input) {
    id
    title
    category
    filePaths
    renewalDate
    notes
    lastModified
    version
    syncState
  }
}
```

**Input:**
```json
{
  "input": {
    "id": "document-id",
    "title": "Updated Insurance Policy",
    "version": 2,
    "syncState": "synced"
  }
}
```

#### Delete Document (Soft Delete)

**Mutation:**
```graphql
mutation UpdateDocument($input: UpdateDocumentInput!) {
  updateDocument(input: $input) {
    id
    deleted
    deletedAt
  }
}
```

**Input:**
```json
{
  "input": {
    "id": "document-id",
    "deleted": true,
    "deletedAt": "2024-01-15T10:30:00Z"
  }
}
```

#### Get Document

**Query:**
```graphql
query GetDocument($id: ID!) {
  getDocument(id: $id) {
    id
    userId
    title
    category
    filePaths
    renewalDate
    notes
    createdAt
    lastModified
    version
    syncState
    conflictId
    deleted
    deletedAt
    fileAttachments {
      items {
        id
        fileName
        label
        fileSize
        s3Key
        addedAt
        syncState
      }
    }
  }
}
```

#### List User Documents

**Query:**
```graphql
query ListDocumentsByUserId($userId: String!, $filter: ModelDocumentFilterInput) {
  listDocuments(filter: $filter) {
    items {
      id
      userId
      title
      category
      filePaths
      renewalDate
      notes
      createdAt
      lastModified
      version
      syncState
      deleted
    }
    nextToken
  }
}
```

**Filter Example (exclude deleted documents):**
```json
{
  "userId": "user-123",
  "filter": {
    "userId": {
      "eq": "user-123"
    },
    "deleted": {
      "ne": true
    }
  }
}
```

### File Attachment Operations

#### Create File Attachment

**Mutation:**
```graphql
mutation CreateFileAttachment($input: CreateFileAttachmentInput!) {
  createFileAttachment(input: $input) {
    id
    documentId
    filePath
    fileName
    label
    fileSize
    s3Key
    addedAt
    syncState
  }
}
```

#### List File Attachments for Document

**Query:**
```graphql
query ListFileAttachmentsByDocumentId($documentId: ID!) {
  listFileAttachments(filter: {documentId: {eq: $documentId}}) {
    items {
      id
      documentId
      filePath
      fileName
      label
      fileSize
      s3Key
      addedAt
      syncState
    }
  }
}
```

### Real-time Subscriptions

#### Document Changes

**Subscription:**
```graphql
subscription OnDocumentChange($userId: String!) {
  onCreateDocument(filter: {userId: {eq: $userId}}) {
    id
    userId
    title
    category
    lastModified
    version
    syncState
  }
}

subscription OnDocumentUpdate($userId: String!) {
  onUpdateDocument(filter: {userId: {eq: $userId}}) {
    id
    userId
    title
    category
    lastModified
    version
    syncState
  }
}
```

#### File Attachment Changes

**Subscription:**
```graphql
subscription OnFileAttachmentChange($documentId: ID!) {
  onCreateFileAttachment(filter: {documentId: {eq: $documentId}}) {
    id
    documentId
    fileName
    s3Key
    syncState
  }
}
```

## Authentication

All API operations require valid AWS Cognito authentication tokens. The API uses owner-based authorization, meaning users can only access their own documents and file attachments.

### Required Headers

```
Authorization: Bearer <cognito-jwt-token>
Content-Type: application/json
```

### Token Refresh

When tokens expire (typically after 1 hour), the client must refresh using the refresh token:

```dart
final result = await Amplify.Auth.fetchAuthSession();
if (result.isSignedIn) {
  final token = result.userPoolTokensResult.value.accessToken.raw;
  // Use token in API calls
}
```

## Error Handling

### Common Error Codes

- `401 Unauthorized`: Invalid or expired authentication token
- `403 Forbidden`: User doesn't have permission to access resource
- `404 Not Found`: Document or file attachment doesn't exist
- `409 Conflict`: Version conflict during update
- `422 Unprocessable Entity`: Validation error
- `500 Internal Server Error`: Server-side error

### Error Response Format

```json
{
  "errors": [
    {
      "message": "Version conflict detected",
      "errorType": "VersionConflictException",
      "path": ["updateDocument"],
      "locations": [{"line": 2, "column": 3}],
      "extensions": {
        "localVersion": 2,
        "remoteVersion": 3,
        "conflictId": "conflict-123"
      }
    }
  ]
}
```

## File Storage (S3)

### Upload File

Files are uploaded to S3 using Amplify Storage:

```dart
final uploadTask = Amplify.Storage.uploadFile(
  localFile: AWSFile.fromPath(filePath),
  key: s3Key,
  options: const StorageUploadFileOptions(
    accessLevel: StorageAccessLevel.private,
  ),
);

final result = await uploadTask.result;
```

### Download File

```dart
final downloadTask = Amplify.Storage.downloadFile(
  key: s3Key,
  localFile: AWSFile.fromPath(localPath),
  options: const StorageDownloadFileOptions(
    accessLevel: StorageAccessLevel.private,
  ),
);

await downloadTask.result;
```

### Delete File

```dart
await Amplify.Storage.remove(
  key: s3Key,
  options: const StorageRemoveOptions(
    accessLevel: StorageAccessLevel.private,
  ),
);
```

### S3 Key Format

Files are stored with the following key format:
```
private/{userId}/documents/{documentId}/{timestamp}-{filename}
```

Example: `private/user-123/documents/doc-456/1704067800000-insurance.pdf`

## Rate Limits

- **GraphQL Operations**: 1000 requests per minute per user
- **File Uploads**: 100 uploads per minute per user
- **File Downloads**: 500 downloads per minute per user
- **Subscriptions**: 10 concurrent subscriptions per user

## Batch Operations

### Batch Document Creation

For efficiency, multiple documents can be created in a single batch:

```dart
final batch = <GraphQLRequest<Document>>[];
for (final document in documents) {
  batch.add(ModelMutations.create(document));
}

// Execute batch (max 25 operations)
final results = await Future.wait(
  batch.map((request) => Amplify.API.mutate(request: request).response)
);
```

### Pagination

Large result sets are paginated using cursor-based pagination:

```graphql
query ListDocuments($limit: Int, $nextToken: String) {
  listDocuments(limit: $limit, nextToken: $nextToken) {
    items {
      id
      title
      category
    }
    nextToken
  }
}
```

## Performance Considerations

### Caching

- **Local Cache**: Documents are cached locally for offline access
- **TTL**: Cache expires after 1 hour or on explicit refresh
- **Invalidation**: Cache is invalidated on document updates

### Optimization Tips

1. **Use Filters**: Always filter queries to reduce data transfer
2. **Pagination**: Use pagination for large result sets
3. **Selective Fields**: Only request needed fields in queries
4. **Batch Operations**: Group multiple operations when possible
5. **Compression**: Large text fields are automatically compressed

### File Upload Optimization

- **Multipart Upload**: Files >5MB use multipart upload
- **Progress Tracking**: Upload progress is reported via streams
- **Resume**: Interrupted uploads can be resumed
- **Parallel Uploads**: Max 3 concurrent file uploads

## Monitoring and Analytics

### Sync Events

All sync operations generate events for monitoring:

```dart
await _createSyncEvent(
  eventType: 'document_upload',
  entityType: 'Document',
  entityId: document.id.toString(),
  message: 'Document uploaded successfully',
);
```

### Performance Metrics

Key metrics tracked:
- Operation latency
- Success/failure rates
- Bandwidth usage
- Error frequencies
- User activity patterns

### Health Checks

API health can be monitored via:
- GraphQL introspection queries
- S3 bucket accessibility
- Authentication service status
- Real-time subscription connectivity