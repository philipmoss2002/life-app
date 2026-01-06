# Immediate Steps to Fix Authorization Errors

## Current Status
✅ GraphQL schema updated with proper authorization rules
✅ All models now have consistent owner-based authorization
⚠️ Changes need to be deployed to AWS AppSync
⚠️ Application code needs updates after deployment

## Step 1: Deploy Schema Changes
```bash
cd household_docs_app
amplify push
```

**Expected prompts:**
- "Are you sure you want to continue?" → **Yes**
- "Do you want to update code for your updated GraphQL API" → **Yes**
- "Do you want to generate GraphQL statements" → **Yes**

This will:
- Deploy the updated schema to AWS AppSync
- Regenerate model classes with new userId fields
- Update GraphQL operations

## Step 2: Fix Compilation Errors
After `amplify push`, you'll get compilation errors because the model constructors have changed. Fix these in order:

### 2.1 FileAttachment Creation
Update these files:
- `lib/services/sync_aware_file_manager.dart`
- `lib/services/database_service.dart`
- `lib/models/model_extensions.dart`

Add `userId` parameter:
```dart
// Before
final attachment = FileAttachment(
  syncId: syncId,
  fileName: fileName,
  // ... other fields
);

// After  
final attachment = FileAttachment(
  syncId: syncId,
  userId: currentUser.id, // Add this line
  fileName: fileName,
  // ... other fields
);
```

### 2.2 Device Creation (if used)
Search for `Device(` and add `userId` field.

### 2.3 SyncEvent Creation (if used)
Search for `SyncEvent(` and add `userId` field.

### 2.4 Conflict Creation (if used)
Search for `Conflict(` and add `userId` field.

## Step 3: Test Authorization
After fixing compilation errors:

1. **Test Document Creation**:
   ```dart
   // Should succeed - creates document in DynamoDB
   final document = Document(
     syncId: SyncIdentifierService.generateValidated(),
     userId: currentUser.id, // This matches the JWT sub claim
     title: "Test Document",
     // ... other fields
   );
   ```

2. **Test Document Listing**:
   ```dart
   // Should only return user's own documents
   final documents = await DocumentSyncManager().fetchAllDocuments(currentUser.id);
   ```

## Step 4: Verify Fix
✅ Documents are created in DynamoDB (no more "Not Authorized" errors)
✅ Users only see their own documents
✅ File uploads continue to work
✅ Sync operations succeed

## Quick Verification Commands
```bash
# Check if deployment succeeded
amplify status

# View the deployed schema
amplify console api

# Check for any remaining issues
flutter analyze
```

## If You Get Stuck
1. **Compilation errors**: Focus on adding `userId` fields to model constructors
2. **Still getting auth errors**: Verify `amplify push` completed successfully
3. **Data access issues**: Check that `currentUser.id` is the Cognito `sub` claim

## Expected Timeline
- Schema deployment: 5-10 minutes
- Code fixes: 15-30 minutes  
- Testing: 10-15 minutes
- **Total**: ~30-60 minutes

The authorization errors should be resolved once these steps are completed.