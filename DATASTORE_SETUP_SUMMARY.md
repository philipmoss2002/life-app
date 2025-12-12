# DataStore Setup Summary

## What Changed

The Household Docs App now uses **Amplify DataStore** instead of manual REST API for cloud synchronization.

## Files Updated

### 1. Dependencies (`pubspec.yaml`)
- ✅ Replaced `amplify_api` with `amplify_datastore`
- ✅ All other dependencies remain the same

### 2. Amplify Service (`lib/services/amplify_service.dart`)
- ✅ Added DataStore plugin initialization
- ✅ Removed API plugin (not needed with DataStore)
- ✅ Ready for generated models

### 3. Documentation Created
- ✅ `AMPLIFY_DATASTORE_GUIDE.md` - Complete DataStore setup guide
- ✅ `DATASTORE_BENEFITS.md` - Why we chose DataStore
- ✅ `DATASTORE_SETUP_SUMMARY.md` - This file
- ✅ Updated `AWS_SETUP_GUIDE.md` with Amplify CLI instructions
- ✅ Updated `CLOUD_SYNC_QUICKSTART.md` with DataStore steps

## What You Need to Do

### Step 1: Install Amplify CLI

```bash
npm install -g @aws-amplify/cli
amplify configure
```

### Step 2: Initialize Amplify

```bash
cd household_docs_app
amplify init
```

### Step 3: Add Services

```bash
# Add authentication
amplify add auth

# Add API with DataStore
amplify add api

# Add storage for files
amplify add storage
```

### Step 4: Define GraphQL Schema

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
```

### Step 5: Push to AWS

```bash
amplify push
```

This creates:
- Cognito User Pool
- AppSync GraphQL API
- DynamoDB tables
- S3 bucket
- Generated Flutter models in `lib/models/`
- Configuration file `lib/amplifyconfiguration.dart`

### Step 6: Update AmplifyService

After `amplify push`, update `lib/services/amplify_service.dart`:

```dart
import 'package:amplify_datastore/amplify_datastore.dart';
import '../models/ModelProvider.dart';
import '../amplifyconfiguration.dart';

// In _addPlugins():
await Amplify.addPlugin(
  AmplifyDataStore(modelProvider: ModelProvider.instance),
);

// In initialize():
await Amplify.configure(amplifyconfig);
```

### Step 7: Use DataStore in Your App

Replace database calls with DataStore:

```dart
// Old way (local SQLite)
await DatabaseService.instance.insertDocument(document);

// New way (DataStore - syncs automatically)
await Amplify.DataStore.save(document);
```

## Key Benefits

### Before (Manual API)
- ❌ Need to write 10-15 Lambda functions
- ❌ Configure API Gateway
- ❌ Write sync logic manually
- ❌ Handle conflicts manually
- ❌ Implement offline queue
- ❌ 2000+ lines of backend code
- ❌ 1-2 weeks development time

### After (DataStore)
- ✅ Zero Lambda functions
- ✅ Zero API configuration
- ✅ Automatic sync
- ✅ Built-in conflict resolution
- ✅ Automatic offline support
- ✅ Zero backend code
- ✅ 1-2 days development time

## How DataStore Works

```
┌─────────────────────────────────────┐
│         Your Flutter App             │
│  ┌───────────────────────────────┐  │
│  │  Amplify.DataStore.save()     │  │
│  │  Amplify.DataStore.query()    │  │
│  │  Amplify.DataStore.observe()  │  │
│  └───────────┬───────────────────┘  │
│              │                       │
│  ┌───────────▼───────────────────┐  │
│  │  Local SQLite (Offline)       │  │
│  └───────────┬───────────────────┘  │
└──────────────┼──────────────────────┘
               │ Auto Sync
               ▼
┌─────────────────────────────────────┐
│           AWS Cloud                  │
│  ┌──────────────────────────────┐  │
│  │  AppSync (GraphQL API)       │  │
│  └──────────┬───────────────────┘  │
│             │                       │
│  ┌──────────▼───────────────────┐  │
│  │  DynamoDB (Cloud Storage)    │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Example Usage

### Create Document

```dart
final document = Document(
  title: 'Car Insurance',
  category: 'Insurance',
  renewalDate: TemporalDateTime(DateTime(2024, 12, 31)),
  notes: 'Policy details',
  version: 1,
  deleted: false,
);

await Amplify.DataStore.save(document);
// Automatically syncs to cloud when online!
```

### Query Documents

```dart
final documents = await Amplify.DataStore.query(
  Document.classType,
  where: Document.DELETED.eq(false),
);
// Works offline! Returns local data immediately.
```

### Real-Time Updates

```dart
Amplify.DataStore.observe(Document.classType).listen((event) {
  print('Document ${event.eventType}: ${event.item.title}');
  // UI updates automatically when data changes!
});
```

### Upload File to S3

```dart
final result = await Amplify.Storage.uploadFile(
  localFile: AWSFile.fromPath(filePath),
  key: 'documents/$documentId/$fileName',
).result;

// Save file metadata to DataStore
final fileAttachment = FileAttachment(
  documentId: documentId,
  fileName: fileName,
  s3Key: result.uploadedItem.key,
  fileSize: fileSize,
);

await Amplify.DataStore.save(fileAttachment);
```

## Migration from Local Database

You'll need to migrate existing local data to DataStore:

```dart
Future<void> migrateToDataStore() async {
  final localDocs = await DatabaseService.instance.getAllDocuments();
  
  for (final localDoc in localDocs) {
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
  }
}
```

## Testing

DataStore can be mocked for testing:

```dart
class MockDataStore extends Mock implements AmplifyDataStore {}

test('should save document', () async {
  final mockDataStore = MockDataStore();
  when(() => mockDataStore.save(any())).thenAnswer((_) async => {});
  
  await mockDataStore.save(document);
  
  verify(() => mockDataStore.save(document)).called(1);
});
```

## Cost Estimate

For 1000 active users:
- **AppSync**: ~$5-10/month
- **DynamoDB**: ~$5-10/month
- **S3**: ~$5-10/month
- **Cognito**: ~$5/month (first 50k MAUs free)

**Total**: ~$20-35/month

Compare to manual API:
- Lambda: ~$10-15/month
- API Gateway: ~$10-15/month
- DynamoDB: ~$5-10/month
- S3: ~$5-10/month
- Cognito: ~$5/month

**Total**: ~$35-55/month

**Savings**: $15-20/month + 1-2 weeks development time!

## Resources

- **Setup Guide**: `AMPLIFY_DATASTORE_GUIDE.md`
- **Benefits**: `DATASTORE_BENEFITS.md`
- **AWS Setup**: `AWS_SETUP_GUIDE.md`
- **Quick Start**: `CLOUD_SYNC_QUICKSTART.md`
- **Official Docs**: https://docs.amplify.aws/lib/datastore/getting-started/q/platform/flutter/

## Troubleshooting

### DataStore not syncing
```dart
await Amplify.DataStore.stop();
await Amplify.DataStore.start();
```

### Clear local data
```dart
await Amplify.DataStore.clear();
```

### Check auth status
```dart
final session = await Amplify.Auth.fetchAuthSession();
print('Signed in: ${session.isSignedIn}');
```

## Next Steps

1. ✅ Dependencies installed
2. ⏳ Install Amplify CLI
3. ⏳ Run `amplify init`
4. ⏳ Add auth, API, storage
5. ⏳ Define GraphQL schema
6. ⏳ Run `amplify push`
7. ⏳ Update AmplifyService
8. ⏳ Replace database calls with DataStore
9. ⏳ Test offline sync
10. ⏳ Deploy to production

You're ready to start! Follow `AMPLIFY_DATASTORE_GUIDE.md` for detailed instructions. 🚀
