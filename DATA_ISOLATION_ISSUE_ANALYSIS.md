# Data Isolation Issue Analysis

## Problem Statement

When a new user creates an account and logs in, they see documents from the previous user. This is a **critical security and privacy issue** that violates user data isolation.

## Root Cause Analysis

### 1. **Local Database is NOT User-Scoped**

The local SQLite database (`household_docs_v2.db`) is stored in a **shared location** that persists across user sessions:

**Location:** `getApplicationSupportDirectory()/databases/household_docs_v2.db`

**Issue:** This database is **NOT cleared** when users sign out or when a new user signs in.

**Evidence from code:**
```dart
// household_docs_app/lib/services/new_database_service.dart
Future<Database> _initDB(String filePath) async {
  final appDir = await getApplicationSupportDirectory();
  final dbDir = Directory(join(appDir.path, 'databases'));
  final path = join(dbDir.path, filePath);  // Same path for all users!
  
  return await openDatabase(path, version: 3, ...);
}
```

### 2. **Sign-Out Does NOT Clear Local Data**

When a user signs out, the authentication service only:
- Clears AWS Cognito session
- Clears cached Identity Pool ID
- Emits auth state change

**What it DOES NOT do:**
- Clear local SQLite database
- Delete local files
- Remove any user-specific data

**Evidence from code:**
```dart
// household_docs_app/lib/services/authentication_service.dart
Future<void> signOut() async {
  try {
    await Amplify.Auth.signOut();
    _cachedIdentityPoolId = null;  // Only clears cache
    _authStateController.add(AuthState(isAuthenticated: false));
  } catch (e) {
    throw AuthenticationException('Sign out failed: ${e.message}');
  }
}
```

### 3. **Sign-In Syncs Remote Data But Doesn't Clear Local First**

When a new user signs in, the sync service:
1. Pulls remote documents for the new user
2. **Merges** them with existing local documents
3. Does NOT clear documents from the previous user

**Evidence from code:**
```dart
// household_docs_app/lib/screens/sign_in_screen.dart
Future<void> _handleSignIn() async {
  await _authService.signIn(email, password);
  
  if (mounted) {
    _syncService.syncOnAppLaunch();  // Syncs but doesn't clear first!
    Navigator.pushReplacement(context, ...);
  }
}
```

```dart
// household_docs_app/lib/services/document_sync_service.dart
Future<void> pullRemoteDocuments() async {
  final userId = await _authService.getUserId();
  final remoteDocs = await _fetchAllRemoteDocuments(userId);
  
  for (final remoteDoc in remoteDocs) {
    final localDoc = await _documentRepository.getDocument(syncId);
    
    if (localDoc == null) {
      await _createLocalDocumentFromMap(remoteDoc);  // Creates new
    } else {
      // Updates existing - but what if it belongs to another user?
      await _updateLocalDocumentFromMap(remoteDoc, localDoc);
    }
  }
}
```

### 4. **Remote Data IS Properly Isolated**

The GraphQL schema correctly implements user isolation using AWS Cognito:

```graphql
type Document @model @auth(rules: [
  {allow: owner, ownerField: "userId", identityClaim: "sub"}
]) {
  syncId: String! @primaryKey
  userId: String! @index(name: "byUserId", sortKeyFields: ["createdAt"])
  ...
}
```

**This means:**
- Remote data (DynamoDB) is properly scoped by `userId`
- Each user can only access their own documents via GraphQL
- The issue is **purely local** - the SQLite database is shared

## Impact Assessment

### Severity: **CRITICAL** 🔴

### Security Implications:
1. **Privacy Violation:** User A can see User B's documents
2. **Data Leakage:** Sensitive information (titles, notes, categories, dates) exposed
3. **File Access:** User A may be able to access User B's file attachments
4. **Compliance Risk:** Violates GDPR, CCPA, and other privacy regulations

### User Experience Impact:
1. Confusing - users see documents they didn't create
2. Trust erosion - users lose confidence in the app
3. Data corruption - users might delete others' documents
4. Sync conflicts - multiple users' data mixed together

## Proposed Solution

### Option 1: **User-Scoped Database (Recommended)** ✅

Create a separate SQLite database for each user, scoped by their Cognito User ID.

**Advantages:**
- Complete data isolation
- No risk of data leakage
- Clean separation of concerns
- Easy to implement

**Implementation:**
```dart
// Modified: lib/services/new_database_service.dart
Future<Database> _initDB(String userId) async {
  final appDir = await getApplicationSupportDirectory();
  final dbDir = Directory(join(appDir.path, 'databases'));
  
  // Create user-specific database
  final dbFileName = 'household_docs_${userId}.db';
  final path = join(dbDir.path, dbFileName);
  
  return await openDatabase(path, version: 3, ...);
}

// Add method to get current user's database
Future<Database> get database async {
  // Get current user ID from auth service
  final userId = await _authService.getUserId();
  
  if (_database != null && _currentUserId == userId) {
    return _database!;
  }
  
  // Close previous database if user changed
  if (_database != null && _currentUserId != userId) {
    await _database!.close();
    _database = null;
  }
  
  _currentUserId = userId;
  _database = await _initDB(userId);
  return _database!;
}
```

**Sign-out changes:**
```dart
// Modified: lib/services/authentication_service.dart
Future<void> signOut() async {
  try {
    // Close current user's database
    await NewDatabaseService.instance.close();
    
    // Sign out from AWS Cognito
    await Amplify.Auth.signOut();
    _cachedIdentityPoolId = null;
    
    // Emit auth state change
    _authStateController.add(AuthState(isAuthenticated: false));
  } catch (e) {
    throw AuthenticationException('Sign out failed: ${e.message}');
  }
}
```

### Option 2: **Clear Database on Sign-Out** ⚠️

Clear all local data when a user signs out.

**Advantages:**
- Simple to implement
- Ensures clean state

**Disadvantages:**
- Loses offline data if user signs out accidentally
- Requires re-download on next sign-in
- Poor user experience for users who frequently switch accounts

**Implementation:**
```dart
Future<void> signOut() async {
  try {
    // Clear all local data
    await NewDatabaseService.instance.clearAllData();
    
    // Delete local files
    await FileService().clearAllLocalFiles();
    
    // Sign out from AWS Cognito
    await Amplify.Auth.signOut();
    _cachedIdentityPoolId = null;
    
    _authStateController.add(AuthState(isAuthenticated: false));
  } catch (e) {
    throw AuthenticationException('Sign out failed: ${e.message}');
  }
}
```

### Option 3: **Add userId Column to Local Database** ⚠️

Add a `userId` column to the local database and filter all queries by current user.

**Advantages:**
- Single database file
- Can support multiple users

**Disadvantages:**
- Complex migration required
- Risk of query bugs (forgetting to filter by userId)
- Doesn't prevent data leakage if queries are incorrect
- More error-prone

## Recommended Implementation Plan

### Phase 1: Immediate Fix (User-Scoped Database)

1. **Modify NewDatabaseService:**
   - Accept userId parameter in `_initDB()`
   - Track current user ID
   - Close and reopen database when user changes
   - Create user-specific database files

2. **Modify AuthenticationService:**
   - Close database on sign-out
   - Ensure database is reopened with new user ID on sign-in

3. **Add Migration Logic:**
   - Detect existing `household_docs_v2.db`
   - If user is authenticated, migrate to user-specific database
   - Delete old shared database after migration

4. **Update All Database Access:**
   - Ensure all services wait for authentication before accessing database
   - Handle case where user is not authenticated (use temporary/guest database)

### Phase 2: Testing

1. **Test Scenarios:**
   - User A signs in → creates documents → signs out
   - User B signs in → should see ONLY their documents
   - User A signs in again → should see their original documents
   - Sign out → sign in with same user → data persists
   - Multiple rapid sign-in/sign-out cycles

2. **Verify:**
   - No data leakage between users
   - Data persists for each user
   - Database files are properly closed/opened
   - No file handle leaks

### Phase 3: Cleanup (Optional)

1. **Add database cleanup:**
   - Delete old user databases after account deletion
   - Implement database size limits
   - Add database vacuum/optimization

2. **Add monitoring:**
   - Log database operations
   - Track database file sizes
   - Monitor for errors

## Additional Considerations

### 1. File Attachments

Local file attachments are also likely shared across users. Need to:
- Store files in user-specific directories
- Clear files on sign-out (if using Option 2)
- Scope file paths by user ID

**Current file storage:**
```dart
// Likely stored in a shared directory
final appDir = await getApplicationDocumentsDirectory();
final filePath = join(appDir.path, 'files', fileName);
```

**Should be:**
```dart
final appDir = await getApplicationDocumentsDirectory();
final userId = await _authService.getUserId();
final filePath = join(appDir.path, 'files', userId, fileName);
```

### 2. Logs

Application logs may also contain sensitive information. Consider:
- Scoping logs by user
- Clearing logs on sign-out
- Redacting sensitive information

### 3. Cached Data

Check for other cached data that might leak between users:
- Shared preferences
- Cached images/thumbnails
- Temporary files

### 4. Guest/Offline Mode

If the app supports offline mode without authentication:
- Use a special "guest" user ID
- Provide option to migrate guest data when user signs up
- Clear guest data after migration

## Security Best Practices

1. **Always scope data by user ID**
2. **Never trust client-side data isolation** - always verify on server
3. **Clear sensitive data on sign-out**
4. **Use separate storage for each user**
5. **Test with multiple users**
6. **Audit all data access points**
7. **Log security-relevant events**

## Conclusion

The root cause is that the local SQLite database is **shared across all users** and is **not cleared on sign-out**. The recommended solution is to implement **user-scoped databases** (Option 1), which provides complete data isolation and the best user experience.

This is a **critical security issue** that should be fixed immediately before releasing to production or adding more users.
