# DynamoDB Document Sync Fix

## 🔍 **Issue Identified**

**Problem**: Files upload successfully to S3, but documents are not created in DynamoDB.

**Root Cause**: Document ID mismatch between local SQLite database and DynamoDB requirements.

## 🔧 **Technical Analysis**

### **The ID Problem**
```dart
// LOCAL DATABASE (SQLite):
final id = await DatabaseService.instance.createDocument(document);
// Returns: integer (e.g., 123, 456, 789)

// DOCUMENT SYNC:
final documentWithId = Document(id: id.toString(), ...);
// Creates: "123", "456", "789"

// DYNAMODB EXPECTATION:
// Expects: UUID format (e.g., "550e8400-e29b-41d4-a716-446655440000")
```

### **GraphQL Schema**
```graphql
type Document @model @auth(rules: [{allow: owner}]) {
  id: ID!  # Expects UUID, not integer string
  userId: String!
  title: String!
  # ...
}
```

## ✅ **Fix Implemented**

### **1. Enhanced Debugging**
Added comprehensive logging to track the sync process:

```dart
// CloudSyncService debugging:
safePrint('📋 Uploading document metadata...');
safePrint('📄 Document title: ${documentToUpload.title}');
safePrint('👤 Document user ID: ${documentToUpload.userId}');
safePrint('📁 Document file paths: ${documentToUpload.filePaths}');

// DocumentSyncManager debugging:
safePrint('📤 Sending GraphQL mutation to DynamoDB...');
safePrint('📋 Document data: ${documentToUpload.title}');
safePrint('❓ Has errors: ${response.hasErrors}');
```

### **2. ID Generation Fix**
Modified GraphQL mutation to let DynamoDB auto-generate IDs:

```dart
// BEFORE (Problematic):
variables: {
  'input': {
    'id': documentToUpload.id,  // Integer string like "123"
    'userId': documentToUpload.userId,
    // ...
  }
}

// AFTER (Fixed):
variables: {
  'input': {
    // Don't include 'id' - let DynamoDB auto-generate UUID
    'userId': documentToUpload.userId,
    // ...
  }
}
```

### **3. Response Handling**
Added logic to handle DynamoDB-generated IDs:

```dart
if (response.data?.id != null && response.data!.id != documentToUpload.id) {
  safePrint('🔄 DynamoDB generated new ID: ${response.data!.id}');
  safePrint('📝 Original local ID was: ${documentToUpload.id}');
  // Note: Caller should update local database with new ID
}
```

## 🧪 **Testing Instructions**

### **1. Test Document Creation**
1. **Hot restart** the app
2. **Create a new document** with files
3. **Watch console logs** for detailed sync process
4. **Check both**:
   - S3 bucket (files should appear)
   - DynamoDB table (document metadata should appear)

### **2. Look for These Log Messages**
```
📋 Uploading document metadata...
📤 Sending GraphQL mutation to DynamoDB...
❓ Has errors: false
✅ Document successfully created in DynamoDB
📄 Created document ID: [UUID]
```

### **3. Expected Behavior**
- ✅ **Files upload to S3** (already working)
- ✅ **Document created in DynamoDB** (should now work)
- ✅ **Sync completes successfully** (no errors)

## 🔮 **Future Considerations**

### **ID Synchronization**
The current fix allows DynamoDB to generate new UUIDs, but the local database still has integer IDs. Consider:

1. **Option 1**: Update local database with DynamoDB UUID after sync
2. **Option 2**: Generate UUIDs locally before creating documents
3. **Option 3**: Use a mapping table between local IDs and remote IDs

### **Recommended Approach**
```dart
// Generate UUID locally before creating document
import 'package:uuid/uuid.dart';

final documentId = const Uuid().v4();
final document = Document(
  id: documentId,  // Use UUID from start
  userId: currentUser.id,
  // ...
);
```

## 📊 **Sync Flow Status**

| Step | Status | Notes |
|------|--------|-------|
| 1. Document created locally | ✅ Working | SQLite database |
| 2. Files uploaded to S3 | ✅ Working | User-isolated paths |
| 3. Document metadata to DynamoDB | ✅ Fixed | UUID generation |
| 4. Local document updated | ⚠️ TODO | Sync new UUID back |
| 5. Sync state updated | ✅ Working | Marked as synced |

## 🎯 **Expected Result**

After this fix, the complete sync process should work:
1. **User creates document** → Local database + files selected
2. **Sync triggered** → Files upload to S3 successfully  
3. **Metadata sync** → Document created in DynamoDB with UUID
4. **Sync complete** → Document marked as synced

**Both S3 files AND DynamoDB metadata should now be created successfully!** 🎉