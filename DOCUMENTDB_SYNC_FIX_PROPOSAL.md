# DocumentDB Sync API Errors - Fix Proposal

## Errors Identified

```
[ERROR] Failed to fetch remote document: ApiOperationException {
  "message": "No modelProvider found",
  "recoverySuggestion": "Pass in a modelProvider instance while instantiating APIPlugin"
}

[ERROR] Failed to create remote document: ApiOperationException {
  "message": "No decodePath found",
  "recoverySuggestion": "Include decodePath when creating a request"
}
```

## Root Causes

### 1. Missing ModelProvider in API Plugin Configuration
**File**: `lib/services/amplify_service.dart`
**Issue**: `AmplifyAPI()` is instantiated without a ModelProvider

**Current Code**:
```dart
await Amplify.addPlugin(AmplifyAPI());
```

**Fix Required**:
```dart
await Amplify.addPlugin(AmplifyAPI(modelProvider: ModelProvider.instance));
```

### 2. Missing amplify_api_dart Dependency
**File**: `pubspec.yaml`
**Issue**: `amplify_api_dart` is not listed as a dependency

**Fix Required**:
```yaml
dependencies:
  amplify_api: ^2.0.0  # Add this line
```

### 3. Incorrect GraphQLRequest Configuration
**File**: `lib/services/document_sync_service.dart`
**Issue**: Custom GraphQLRequest missing `decodePath` parameter

**Current Code** (in _createRemoteDocument):
```dart
final request = GraphQLRequest<remote.Document>(
  document: '''mutation...''',
  variables: {...},
  modelType: remote.Document.classType,
);
```

**Fix Required**: Use `ModelMutations` helper instead:
```dart
final request = ModelMutations.create(remoteDoc);
```

### 4. Mixed Approach
**Issue**: Some methods use `ModelMutations`/`ModelQueries` (correct) while `_createRemoteDocument` uses custom `GraphQLRequest` (incorrect)

## Proposed Fixes

### Fix 1: Update amplify_service.dart

```dart
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_storage_s3/amplify_storage_s3.dart';
import 'package:amplify_api/amplify_api.dart';
import '../models/ModelProvider.dart';  // ADD THIS
import 'security_config_service.dart';

class AmplifyService {
  // ... existing code ...

  Future<void> _addPlugins() async {
    try {
      // Add Auth plugin
      await Amplify.addPlugin(AmplifyAuthCognito());
      safePrint('Auth plugin added');

      // Add API plugin with ModelProvider (FIXED)
      await Amplify.addPlugin(
        AmplifyAPI(modelProvider: ModelProvider.instance)
      );
      safePrint('API plugin added');

      // Add Storage plugin
      await Amplify.addPlugin(AmplifyStorageS3());
      safePrint('Storage plugin added');
    } catch (e) {
      safePrint('Error adding plugins: $e');
      rethrow;
    }
  }
}
```

### Fix 2: Update pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter

  # ... existing dependencies ...
  
  # AWS Amplify packages for cloud sync
  amplify_flutter: ^2.0.0
  amplify_auth_cognito: ^2.0.0
  amplify_storage_s3: ^2.0.0
  amplify_api: ^2.0.0  # ADD THIS LINE
  amplify_core: ^2.0.0
```

### Fix 3: Update document_sync_service.dart

Replace the custom GraphQLRequest in `_createRemoteDocument` with `ModelMutations`:

```dart
/// Create a new document in DocumentDB
Future<void> _createRemoteDocument(
  local.Document localDoc,
  String userId,
) async {
  try {
    final remoteDoc = remote.Document(
      syncId: localDoc.syncId,
      userId: userId,
      title: localDoc.title,
      category: _mapCategoryToRemote(localDoc.category),
      renewalDate: localDoc.date != null
          ? TemporalDateTime(localDoc.date!)
          : null,
      notes: localDoc.notes,
      createdAt: TemporalDateTime(localDoc.createdAt),
      lastModified: TemporalDateTime(localDoc.updatedAt),
      syncState: localDoc.syncState.name,
      deleted: false,
      filePaths: [],
      version: 1,
    );

    // Use ModelMutations helper (FIXED)
    final request = ModelMutations.create(remoteDoc);
    final response = await Amplify.API.mutate(request: request).response;

    if (response.hasErrors) {
      throw DocumentSyncException(
        'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
      );
    }

    _logService.log(
      'Created remote document: ${localDoc.syncId}',
      level: log_svc.LogLevel.info,
    );
  } catch (e) {
    _logService.log(
      'Failed to create remote document: $e',
      level: log_svc.LogLevel.error,
    );
    rethrow;
  }
}
```

### Fix 4: Remove amplify_api_dart import

In `document_sync_service.dart`, remove the incorrect import:

```dart
// REMOVE THIS LINE:
// import 'package:amplify_api_dart/amplify_api_dart.dart';

// Keep only:
import 'package:amplify_flutter/amplify_flutter.dart';
```

The `ModelMutations` and `ModelQueries` are available from `amplify_api` package, not `amplify_api_dart`.

## Implementation Steps

1. **Update pubspec.yaml**
   - Add `amplify_api: ^2.0.0` to dependencies
   - Run `flutter pub get`

2. **Update amplify_service.dart**
   - Import `ModelProvider`
   - Pass `ModelProvider.instance` to `AmplifyAPI()`

3. **Update document_sync_service.dart**
   - Remove `amplify_api_dart` import
   - Replace custom GraphQLRequest with `ModelMutations.create()`

4. **Restart the app**
   - Hot restart won't work for Amplify plugin changes
   - Full app restart required

5. **Test sync**
   - Create a document
   - Check logs for successful sync
   - Verify document appears in DocumentDB

## Why This Happens

### ModelProvider
The `AmplifyAPI` plugin needs a `ModelProvider` to:
- Decode GraphQL responses into Dart models
- Serialize Dart models into GraphQL mutations
- Handle model relationships and types

Without it, the API plugin doesn't know how to work with your models.

### ModelMutations vs Custom GraphQLRequest
- `ModelMutations.create()` automatically:
  - Generates correct GraphQL mutation
  - Includes all required fields
  - Sets up proper decoding
  - Handles model serialization

- Custom `GraphQLRequest` requires:
  - Manual GraphQL string
  - Manual variable mapping
  - Manual `decodePath` configuration
  - More error-prone

## Expected Result After Fix

```
[INFO] Syncing document: b245924d-cda4-4454-a61f-fe837da94e53
[INFO] Pushing document to remote: b245924d-cda4-4454-a61f-fe837da94e53
[INFO] Created remote document: b245924d-cda4-4454-a61f-fe837da94e53
[INFO] Document pushed successfully: b245924d-cda4-4454-a61f-fe837da94e53
[INFO] Uploading files for document: b245924d-cda4-4454-a61f-fe837da94e53
[INFO] All files uploaded for document: b245924d-cda4-4454-a61f-fe837da94e53
```

## Verification

After implementing fixes:

1. **Check Amplify initialization**:
   ```dart
   // Should see in logs:
   // Auth plugin added
   // API plugin added
   // Storage plugin added
   // Amplify configured successfully
   ```

2. **Test document creation**:
   - Create a new document
   - Check logs for "Created remote document"
   - Verify no API errors

3. **Check DocumentDB**:
   - Open AWS AppSync console
   - Run query: `listDocuments`
   - Verify document appears

4. **Test multi-device sync**:
   - Create document on Device A
   - Run sync on Device B
   - Verify document appears on Device B

## Additional Notes

### Why amplify_api_dart Doesn't Work
- `amplify_api_dart` is a lower-level package
- It doesn't include the model helpers
- Use `amplify_api` instead (higher-level, includes helpers)

### ModelProvider.instance
- Generated by Amplify CLI
- Located in `lib/models/ModelProvider.dart`
- Singleton instance that knows about all your models
- Must be passed to API plugin for model operations

## Summary

The fix is straightforward:
1. Add `amplify_api` dependency
2. Pass `ModelProvider.instance` to `AmplifyAPI()`
3. Use `ModelMutations.create()` instead of custom GraphQLRequest
4. Remove `amplify_api_dart` import

This will resolve all API errors and enable proper DocumentDB sync.
