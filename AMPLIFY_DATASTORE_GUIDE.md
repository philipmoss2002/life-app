# Amplify DataStore Setup Guide

This guide explains how to use AWS Amplify DataStore for automatic synchronization of your Household Docs data.

## What is Amplify DataStore?

Amplify DataStore provides:
- **Automatic sync** between local SQLite and cloud (DynamoDB + AppSync)
- **Built-in conflict resolution** with customizable strategies
- **Offline-first** architecture - works seamlessly offline
- **Real-time updates** across devices
- **Type-safe models** generated from GraphQL schema
- **No manual API calls** - DataStore handles everything

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                   Flutter App                            │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Your Code (Screens, Services)                     │ │
│  └────────────────┬───────────────────────────────────┘ │
│                   │                                      │
│  ┌────────────────▼───────────────────────────────────┐ │
│  │  Amplify DataStore (Local SQLite)                  │ │
│  │  - Offline storage                                 │ │
│  │  - Query interface                                 │ │
│  │  - Conflict resolution                             │ │
│  └────────────────┬───────────────────────────────────┘ │
└───────────────────┼──────────────────────────────────────┘
                    │ Auto Sync
                    ▼
┌─────────────────────────────────────────────────────────┐
│                   AWS Cloud                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   AppSync    │  │   DynamoDB   │  │      S3      │ │
│  │  (GraphQL)   │◄─┤  (Metadata)  │  │   (Files)    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐                                       │
│  │   Cognito    │                                       │
│  │    (Auth)    │                                       │
│  └──────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

## Setup Steps

### 1. Install Amplify CLI

```bash
npm install -g @aws-amplify/cli
amplify configure
```

Follow the prompts to configure Amplify with your AWS credentials.

### 2. Initialize Amplify in Your Project

```bash
cd household_docs_app
amplify init
```

Configuration:
- Project name: `householdDocsApp`
- Environment: `dev`
- Default editor: Your choice
- App type: `flutter`
- Distribution directory: `build`

### 3. Add DataStore with GraphQL API

```bash
amplify add api
```

Configuration:
- Service: `GraphQL`
- API name: `householdDocsAPI`
- Authorization mode: `Amazon Cognito User Pool`
- Configure additional auth types: `No`
- Do you have an annotated GraphQL schema: `No`
- Do you want a guided schema creation: `Yes`
- What best describes your project: `One-to-many relationship`
- Do you want to edit the schema now: `Yes`

### 4. Define Your GraphQL Schema

Edit `amplify/backend/api/householdDocsAPI/schema.graphql`:

```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!
  title: String!
  category: String!
  renewalDate: AWSDateTime
  notes: String
  createdAt: AWSDateTime!
  lastModified: AWSDateTime!
  version: Int!
  deleted: Boolean!
  fileAttachments: [FileAttachment] @hasMany(indexName: "byDocument", fields: ["id"])
}

type FileAttachment @model @auth(rules: [{allow: owner}]) {
  id: ID!
  documentId: ID! @index(name: "byDocument", sortKeyFields: ["createdAt"])
  fileName: String!
  label: String
  fileSize: Int!
  s3Key: String!
  localPath: String
  createdAt: AWSDateTime!
  document: Document @belongsTo(fields: ["documentId"])
}

type Device @model @auth(rules: [{allow: owner}]) {
  id: ID!
  deviceName: String!
  deviceType: String!
  lastSyncTime: AWSDateTime!
  isActive: Boolean!
}

type SyncQueue @model @auth(rules: [{allow: owner}]) {
  id: ID!
  operation: String!
  entityType: String!
  entityId: String!
  timestamp: AWSDateTime!
  expiresAt: AWSDateTime @ttl
}
```

**Key Features:**
- `@model`: Creates DynamoDB table and CRUD operations
- `@auth(rules: [{allow: owner}])`: User can only access their own data
- `@hasMany` / `@belongsTo`: Defines relationships
- `@index`: Creates secondary indexes for efficient queries
- `@ttl`: Automatic deletion after expiration (for sync queue)

### 5. Add Authentication

```bash
amplify add auth
```

Configuration:
- Default configuration: `Default configuration with Social Provider`
- Sign-in method: `Email`
- Advanced settings: Configure as needed

### 6. Add Storage for Files

```bash
amplify add storage
```

Configuration:
- Service: `Content (Images, audio, video, etc.)`
- Resource name: `householdDocsFiles`
- Bucket name: Auto-generated
- Access: `Auth users only`
- Access level: `Private` (per-user storage)

### 7. Push to AWS

```bash
amplify push
```

This will:
- Create all AWS resources (AppSync, DynamoDB, S3, Cognito)
- Generate Flutter models in `lib/models/`
- Generate `amplifyconfiguration.dart`

### 8. Update Your Code

After `amplify push`, you'll have generated models. Update `AmplifyService`:

```dart
import 'package:amplify_datastore/amplify_datastore.dart';
import '../models/ModelProvider.dart'; // Generated by Amplify

// In _addPlugins():
await Amplify.addPlugin(
  AmplifyDataStore(modelProvider: ModelProvider.instance),
);
```

## Using DataStore in Your App

### Basic CRUD Operations

#### Create a Document

```dart
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';

Future<void> createDocument() async {
  final document = Document(
    title: 'Car Insurance',
    category: 'Insurance',
    renewalDate: TemporalDateTime(DateTime(2024, 12, 31)),
    notes: 'Policy details...',
    version: 1,
    deleted: false,
  );

  try {
    await Amplify.DataStore.save(document);
    print('Document saved: ${document.id}');
  } catch (e) {
    print('Error saving document: $e');
  }
}
```

#### Query Documents

```dart
Future<List<Document>> getAllDocuments() async {
  try {
    final documents = await Amplify.DataStore.query(
      Document.classType,
      where: Document.DELETED.eq(false),
    );
    return documents;
  } catch (e) {
    print('Error querying documents: $e');
    return [];
  }
}

Future<List<Document>> getDocumentsByCategory(String category) async {
  try {
    final documents = await Amplify.DataStore.query(
      Document.classType,
      where: Document.CATEGORY.eq(category).and(Document.DELETED.eq(false)),
    );
    return documents;
  } catch (e) {
    print('Error querying documents: $e');
    return [];
  }
}
```

#### Update a Document

```dart
Future<void> updateDocument(Document document) async {
  try {
    final updatedDocument = document.copyWith(
      title: 'Updated Title',
      version: document.version + 1,
      lastModified: TemporalDateTime.now(),
    );
    
    await Amplify.DataStore.save(updatedDocument);
    print('Document updated');
  } catch (e) {
    print('Error updating document: $e');
  }
}
```

#### Delete a Document (Soft Delete)

```dart
Future<void> deleteDocument(Document document) async {
  try {
    final deletedDocument = document.copyWith(
      deleted: true,
      lastModified: TemporalDateTime.now(),
    );
    
    await Amplify.DataStore.save(deletedDocument);
    print('Document deleted');
  } catch (e) {
    print('Error deleting document: $e');
  }
}
```

### Real-Time Updates

Listen to changes in real-time:

```dart
StreamSubscription? _subscription;

void observeDocuments() {
  _subscription = Amplify.DataStore.observe(Document.classType).listen(
    (event) {
      print('Document event: ${event.eventType}');
      print('Document: ${event.item}');
      
      // Update UI based on event type
      switch (event.eventType) {
        case EventType.create:
          // Handle new document
          break;
        case EventType.update:
          // Handle updated document
          break;
        case EventType.delete:
          // Handle deleted document
          break;
      }
    },
    onError: (error) => print('Error observing documents: $error'),
  );
}

@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### Working with Relationships

```dart
// Create document with file attachments
Future<void> createDocumentWithFiles() async {
  final document = Document(
    title: 'Car Insurance',
    category: 'Insurance',
    version: 1,
    deleted: false,
  );
  
  await Amplify.DataStore.save(document);
  
  // Add file attachment
  final fileAttachment = FileAttachment(
    documentId: document.id,
    fileName: 'policy.pdf',
    label: 'Insurance Policy',
    fileSize: 1024000,
    s3Key: 'files/${document.id}/policy.pdf',
  );
  
  await Amplify.DataStore.save(fileAttachment);
}

// Query document with its file attachments
Future<void> getDocumentWithFiles(String documentId) async {
  final document = await Amplify.DataStore.query(
    Document.classType,
    where: Document.ID.eq(documentId),
  );
  
  if (document.isNotEmpty) {
    final files = await Amplify.DataStore.query(
      FileAttachment.classType,
      where: FileAttachment.DOCUMENTID.eq(documentId),
    );
    
    print('Document: ${document.first.title}');
    print('Files: ${files.length}');
  }
}
```

## Sync Management

### Start/Stop Sync

```dart
// Start DataStore (begins syncing)
await Amplify.DataStore.start();

// Stop DataStore (stops syncing, keeps local data)
await Amplify.DataStore.stop();

// Clear local data and re-sync from cloud
await Amplify.DataStore.clear();
await Amplify.DataStore.start();
```

### Monitor Sync Status

```dart
Amplify.Hub.listen(HubChannel.DataStore, (event) {
  if (event.eventName == 'ready') {
    print('DataStore is ready');
  } else if (event.eventName == 'syncQueriesStarted') {
    print('Sync started');
  } else if (event.eventName == 'syncQueriesReady') {
    print('Sync completed');
  } else if (event.eventName == 'networkStatus') {
    print('Network status: ${event.payload}');
  }
});
```

## Conflict Resolution

DataStore uses **Auto-merge** by default (last writer wins). You can customize:

### Custom Conflict Handler

```dart
await Amplify.addPlugin(
  AmplifyDataStore(
    modelProvider: ModelProvider.instance,
    conflictHandler: (conflict) async {
      // conflict.local - local version
      // conflict.remote - remote version
      
      // Custom logic: keep version with higher version number
      if (conflict.local is Document && conflict.remote is Document) {
        final local = conflict.local as Document;
        final remote = conflict.remote as Document;
        
        return local.version > remote.version 
          ? ConflictResolutionDecision.applyLocal()
          : ConflictResolutionDecision.applyRemote();
      }
      
      // Default: use remote
      return ConflictResolutionDecision.applyRemote();
    },
  ),
);
```

## File Storage with S3

DataStore handles metadata, but files go to S3:

```dart
import 'package:amplify_storage_s3/amplify_storage_s3.dart';

// Upload file
Future<String> uploadFile(String filePath, String documentId) async {
  final file = File(filePath);
  final fileName = path.basename(filePath);
  final key = 'documents/$documentId/$fileName';
  
  try {
    final result = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      key: key,
      options: const StorageUploadFileOptions(
        accessLevel: StorageAccessLevel.private,
      ),
    ).result;
    
    return result.uploadedItem.key;
  } catch (e) {
    print('Error uploading file: $e');
    rethrow;
  }
}

// Download file
Future<String> downloadFile(String s3Key, String localPath) async {
  try {
    final result = await Amplify.Storage.downloadFile(
      key: s3Key,
      localFile: AWSFile.fromPath(localPath),
      options: const StorageDownloadFileOptions(
        accessLevel: StorageAccessLevel.private,
      ),
    ).result;
    
    return result.localFile.path;
  } catch (e) {
    print('Error downloading file: $e');
    rethrow;
  }
}
```

## Migration from Local SQLite

To migrate existing local data to DataStore:

```dart
Future<void> migrateLocalDataToDataStore() async {
  // 1. Get all local documents from your existing DatabaseService
  final localDocuments = await DatabaseService.instance.getAllDocuments();
  
  // 2. Convert and save to DataStore
  for (final localDoc in localDocuments) {
    final datastoreDoc = Document(
      title: localDoc.title,
      category: localDoc.category,
      renewalDate: localDoc.renewalDate != null 
        ? TemporalDateTime(localDoc.renewalDate!)
        : null,
      notes: localDoc.notes,
      version: 1,
      deleted: false,
    );
    
    await Amplify.DataStore.save(datastoreDoc);
    
    // Migrate file attachments
    for (final filePath in localDoc.filePaths) {
      // Upload file to S3
      final s3Key = await uploadFile(filePath, datastoreDoc.id);
      
      // Create FileAttachment record
      final fileAttachment = FileAttachment(
        documentId: datastoreDoc.id,
        fileName: path.basename(filePath),
        fileSize: File(filePath).lengthSync(),
        s3Key: s3Key,
        localPath: filePath,
      );
      
      await Amplify.DataStore.save(fileAttachment);
    }
  }
  
  print('Migration complete: ${localDocuments.length} documents migrated');
}
```

## Testing

### Mock DataStore for Testing

```dart
// In your tests
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:mocktail/mocktail.dart';

class MockAmplifyDataStore extends Mock implements AmplifyDataStore {}

void main() {
  late MockAmplifyDataStore mockDataStore;
  
  setUp(() {
    mockDataStore = MockAmplifyDataStore();
  });
  
  test('should save document', () async {
    final document = Document(title: 'Test', category: 'Test', version: 1, deleted: false);
    
    when(() => mockDataStore.save(document))
      .thenAnswer((_) async => {});
    
    await mockDataStore.save(document);
    
    verify(() => mockDataStore.save(document)).called(1);
  });
}
```

## Best Practices

1. **Always use DataStore for data operations** - Don't mix with direct SQLite access
2. **Handle offline gracefully** - DataStore queues changes automatically
3. **Use observe() for real-time UI updates** - More efficient than polling
4. **Implement proper error handling** - Network issues, conflicts, etc.
5. **Clear DataStore on sign-out** - Prevents data leakage between users
6. **Use soft deletes** - Allows sync of deletions across devices
7. **Version your models** - Track changes for conflict resolution
8. **Test offline scenarios** - Ensure app works without connectivity

## Troubleshooting

### DataStore not syncing

```dart
// Check sync status
Amplify.Hub.listen(HubChannel.DataStore, (event) {
  print('DataStore event: ${event.eventName}');
  print('Payload: ${event.payload}');
});

// Force sync
await Amplify.DataStore.stop();
await Amplify.DataStore.start();
```

### Clear local data

```dart
// Clear all local DataStore data
await Amplify.DataStore.clear();
```

### Check authentication

```dart
final session = await Amplify.Auth.fetchAuthSession();
print('Is signed in: ${session.isSignedIn}');
```

## Resources

- [Amplify DataStore Documentation](https://docs.amplify.aws/lib/datastore/getting-started/q/platform/flutter/)
- [GraphQL Schema Design](https://docs.amplify.aws/cli/graphql/data-modeling/)
- [Conflict Resolution](https://docs.amplify.aws/lib/datastore/conflict/q/platform/flutter/)
- [Real-time Updates](https://docs.amplify.aws/lib/datastore/real-time/q/platform/flutter/)

## Next Steps

1. Run `amplify init` and `amplify add api`
2. Define your GraphQL schema
3. Run `amplify push` to create resources
4. Update `AmplifyService` with generated models
5. Replace local database calls with DataStore operations
6. Test offline sync functionality
7. Implement conflict resolution strategy
8. Add real-time observers to UI

DataStore will handle all the sync complexity for you! 🚀
