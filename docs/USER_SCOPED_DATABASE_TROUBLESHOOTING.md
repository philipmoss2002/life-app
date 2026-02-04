# User-Scoped Database Troubleshooting Guide

## Overview

This guide provides solutions to common issues with the user-scoped database feature. Use this guide when experiencing problems with database switching, migration, guest mode, or data isolation.

---

## Quick Diagnostics

### Check Current Database State

To diagnose database issues, check the application logs:

1. Open the app
2. Navigate to Settings → View Logs
3. Filter by "database" or "migration"
4. Look for error messages or warnings

### Common Log Messages

**Normal Operation:**
```
[INFO] Opening database for user: abc123
[INFO] Database opened: household_docs_abc123.db
[INFO] Switching database from abc123 to xyz789
[INFO] Database switch complete
[INFO] Closing database for user: abc123
```

**Migration:**
```
[INFO] User not migrated, starting migration
[INFO] Migrating legacy database for user: abc123
[INFO] Migration complete: 42 documents, 15 files
```

**Errors:**
```
[ERROR] Failed to open database: [error details]
[ERROR] Migration failed: [error details]
[WARNING] Failed to get user ID: [error details]
```

---

## Common Issues

### Issue 1: Migration Not Occurring

**Symptoms:**
- User signs in but doesn't see their old documents
- No migration log messages
- Documents appear to be missing

**Possible Causes:**

#### Cause 1.1: User Already Migrated

**Diagnosis:**
Check SharedPreferences for migration status:
```dart
final prefs = await SharedPreferences.getInstance();
final migratedUsers = prefs.getStringList('migrated_users') ?? [];
print('Migrated users: $migratedUsers');
```

**Solution:**
If user is in the list but documents are missing, the migration may have failed. Force re-migration:

1. Clear migration status:
```dart
final prefs = await SharedPreferences.getInstance();
final migratedUsers = prefs.getStringList('migrated_users') ?? [];
migratedUsers.remove(userId);
await prefs.setStringList('migrated_users', migratedUsers);
```

2. Sign out and sign in again to trigger migration

#### Cause 1.2: Legacy Database Doesn't Exist

**Diagnosis:**
Check if legacy database file exists:
```dart
final dbPath = await getDatabasesPath();
final legacyPath = join(dbPath, 'household_docs_v2.db');
final legacyFile = File(legacyPath);
print('Legacy database exists: ${await legacyFile.exists()}');
```

**Solution:**
If legacy database doesn't exist, there's nothing to migrate. This is normal for:
- New installations
- Users who never used the old version
- Devices where legacy database was already deleted

#### Cause 1.3: Migration Failed Silently

**Diagnosis:**
Check logs for migration errors:
```
[ERROR] Migration failed: [error details]
```

**Solution:**
1. Check available disk space (need at least 2x database size)
2. Check database file permissions
3. Try manual migration:
```dart
try {
  await NewDatabaseService.instance.migrateLegacyDatabase(userId);
} catch (e) {
  print('Migration error: $e');
}
```

### Issue 2: Database Not Switching

**Symptoms:**
- User A signs out, User B signs in
- User B sees User A's documents
- Wrong database file is open

**Possible Causes:**

#### Cause 2.1: Cached User ID Not Updating

**Diagnosis:**
Check current user ID in database service:
```dart
print('Current user ID: ${NewDatabaseService.instance._currentUserId}');
print('Auth user ID: ${await AuthenticationService().getUserId()}');
```

**Solution:**
Force database close and reopen:
```dart
await NewDatabaseService.instance.close();
// Next database access will open correct database
```

#### Cause 2.2: Database Switch In Progress

**Diagnosis:**
Check if switch is already happening:
```dart
print('Is switching: ${NewDatabaseService.instance._isSwitching}');
```

**Solution:**
Wait for current switch to complete. If stuck:
1. Restart the app
2. Check logs for errors during switch
3. Ensure no long-running database operations

#### Cause 2.3: Authentication State Not Updating

**Diagnosis:**
Check authentication state:
```dart
final isAuth = await AuthenticationService().isAuthenticated();
final userId = await AuthenticationService().getUserId();
print('Authenticated: $isAuth, User ID: $userId');
```

**Solution:**
1. Sign out completely
2. Close app
3. Reopen app
4. Sign in again

### Issue 3: Guest Data Not Migrating

**Symptoms:**
- User creates documents as guest
- Signs in
- No migration prompt appears
- Guest documents not in user account

**Possible Causes:**

#### Cause 3.1: Guest Database Empty

**Diagnosis:**
Check if guest database has documents:
```dart
final guestDbPath = await getDatabasesPath();
final guestPath = join(guestDbPath, 'household_docs_guest.db');
final guestDb = await openDatabase(guestPath, readOnly: true);
final count = Sqflite.firstIntValue(
  await guestDb.rawQuery('SELECT COUNT(*) FROM documents')
);
print('Guest documents: $count');
await guestDb.close();
```

**Solution:**
If count is 0, there's no guest data to migrate. This is normal if:
- User never used guest mode
- Guest database was already cleared
- Documents were deleted before sign-in

#### Cause 3.2: Migration Prompt Not Implemented

**Diagnosis:**
Check if GuestDataMigrationService is being called:
```
[INFO] Checking for guest data
[INFO] Guest data found: X documents
```

**Solution:**
Ensure sign-in flow calls guest data migration check:
```dart
// In sign-in flow
final migrationService = GuestDataMigrationService();
if (await migrationService.hasGuestData()) {
  // Show migration prompt to user
  final shouldMigrate = await showMigrationDialog();
  if (shouldMigrate) {
    await migrationService.migrateGuestData();
  }
}
```

#### Cause 3.3: Migration Failed

**Diagnosis:**
Check logs for migration errors:
```
[ERROR] Guest data migration failed: [error details]
```

**Solution:**
1. Check available disk space
2. Verify guest database is not corrupted
3. Try manual migration:
```dart
try {
  await GuestDataMigrationService().migrateGuestData();
} catch (e) {
  print('Guest migration error: $e');
}
```

### Issue 4: File Access Errors

**Symptoms:**
- Cannot upload files
- Cannot download files
- File not found errors
- Files appear in wrong user's directory

**Possible Causes:**

#### Cause 4.1: Wrong User Directory

**Diagnosis:**
Check which directory is being used:
```dart
final fileService = FileService();
final userDir = await fileService._getUserFileDirectory();
print('User file directory: ${userDir.path}');
```

**Solution:**
Ensure FileService is getting correct user ID:
```dart
// Should return current authenticated user ID or 'guest'
final userId = await AuthenticationService().getUserId();
print('Current user ID: $userId');
```

#### Cause 4.2: Directory Doesn't Exist

**Diagnosis:**
Check if user directory exists:
```dart
final userDir = await fileService._getUserFileDirectory();
print('Directory exists: ${await userDir.exists()}');
```

**Solution:**
Directory should be created automatically. If not:
```dart
final userDir = await fileService._getUserFileDirectory();
if (!await userDir.exists()) {
  await userDir.create(recursive: true);
}
```

#### Cause 4.3: File Permissions

**Diagnosis:**
Check file permissions (platform-specific):
```dart
// On iOS/Android, app has full access to app documents directory
// Check if path is within app documents directory
final appDir = await getApplicationDocumentsDirectory();
print('App directory: ${appDir.path}');
print('File path: $filePath');
print('Is within app dir: ${filePath.startsWith(appDir.path)}');
```

**Solution:**
Ensure files are stored within app documents directory:
- iOS: `/var/mobile/Containers/Data/Application/{UUID}/Documents/`
- Android: `/data/data/{package}/files/`

### Issue 5: Database Corruption

**Symptoms:**
- App crashes when accessing database
- "Database disk image is malformed" error
- Cannot open database

**Possible Causes:**

#### Cause 5.1: Incomplete Write

**Diagnosis:**
Check logs for errors during database operations:
```
[ERROR] Database operation failed: [error details]
```

**Solution:**
1. Close app completely
2. Reopen app (will attempt to open database)
3. If still corrupted, create new database:
```dart
// Backup corrupted database
final dbPath = await getDatabasesPath();
final dbFile = File(join(dbPath, 'household_docs_{userId}.db'));
await dbFile.rename(join(dbPath, 'household_docs_{userId}.db.corrupted'));

// Next database access will create new database
```

#### Cause 5.2: Disk Full

**Diagnosis:**
Check available disk space:
```dart
// Platform-specific code needed
// iOS: Use FileManager
// Android: Use StatFs
```

**Solution:**
1. Free up disk space
2. Delete old databases:
```dart
final databases = await NewDatabaseService.instance.listUserDatabases();
// Delete old/unused databases
```

#### Cause 5.3: Concurrent Access

**Diagnosis:**
Check if multiple processes are accessing database:
```
[ERROR] Database locked
```

**Solution:**
Ensure only one database connection is open:
```dart
// Close any open connections
await NewDatabaseService.instance.close();

// Reopen database
final db = await NewDatabaseService.instance.database;
```

### Issue 6: Rapid Authentication Changes

**Symptoms:**
- App becomes unresponsive during rapid sign-in/sign-out
- Database errors during authentication changes
- Data appears corrupted

**Possible Causes:**

#### Cause 6.1: Concurrent Database Switches

**Diagnosis:**
Check logs for concurrent switch attempts:
```
[ERROR] Database switch already in progress
```

**Solution:**
The mutex should prevent this. If occurring:
1. Restart app
2. Avoid rapid authentication changes
3. Wait for operations to complete before signing out

#### Cause 6.2: Operations Not Completing

**Diagnosis:**
Check for long-running operations:
```
[INFO] Waiting for operation to complete
```

**Solution:**
Ensure operations complete before database switch:
```dart
// In sign-out flow
await NewDatabaseService.instance.close(); // Waits for operations
await AuthenticationService().signOut();
```

#### Cause 6.3: Debouncing Not Working

**Diagnosis:**
Check if multiple auth state changes are firing:
```
[INFO] Auth state changed: authenticated
[INFO] Auth state changed: unauthenticated
[INFO] Auth state changed: authenticated
```

**Solution:**
Implement debouncing in auth state listener:
```dart
authStateStream
  .debounceTime(Duration(milliseconds: 500))
  .listen((state) {
    // Handle auth state change
  });
```

---

## Advanced Diagnostics

### Inspect Database Contents

To manually inspect a database:

1. **Get database path:**
```dart
final dbPath = await getDatabasesPath();
print('Database directory: $dbPath');
```

2. **Copy database to computer:**
   - iOS: Use Xcode → Devices → Download Container
   - Android: Use `adb pull /data/data/{package}/databases/`

3. **Open with SQLite browser:**
   - Download DB Browser for SQLite
   - Open database file
   - Inspect tables and data

### Check Database Schema

Verify database schema is correct:

```dart
final db = await NewDatabaseService.instance.database;
final tables = await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type='table'"
);
print('Tables: $tables');

// Check documents table
final documentsInfo = await db.rawQuery('PRAGMA table_info(documents)');
print('Documents schema: $documentsInfo');
```

### Monitor Database Operations

Add logging to track all database operations:

```dart
// In NewDatabaseService
Future<T> _loggedOperation<T>(
  String operation,
  Future<T> Function() fn,
) async {
  final start = DateTime.now();
  _logService.log('Starting: $operation', level: LogLevel.debug);
  
  try {
    final result = await fn();
    final duration = DateTime.now().difference(start);
    _logService.log(
      'Completed: $operation (${duration.inMilliseconds}ms)',
      level: LogLevel.debug,
    );
    return result;
  } catch (e) {
    _logService.log(
      'Failed: $operation - $e',
      level: LogLevel.error,
    );
    rethrow;
  }
}
```

### Test Database Isolation

Verify complete data isolation:

```dart
// Test script
Future<void> testIsolation() async {
  // Sign in as User A
  await AuthenticationService().signIn('userA@example.com', 'password');
  final dbA = await NewDatabaseService.instance.database;
  await dbA.insert('documents', {'syncId': 'doc-a', 'title': 'User A Doc'});
  await AuthenticationService().signOut();
  
  // Sign in as User B
  await AuthenticationService().signIn('userB@example.com', 'password');
  final dbB = await NewDatabaseService.instance.database;
  final docsB = await dbB.query('documents');
  
  // Should be empty (no User A documents)
  assert(docsB.isEmpty, 'User B should not see User A documents');
  
  await dbB.insert('documents', {'syncId': 'doc-b', 'title': 'User B Doc'});
  await AuthenticationService().signOut();
  
  // Sign in as User A again
  await AuthenticationService().signIn('userA@example.com', 'password');
  final dbA2 = await NewDatabaseService.instance.database;
  final docsA = await dbA2.query('documents');
  
  // Should only have User A's document
  assert(docsA.length == 1, 'User A should see only their document');
  assert(docsA[0]['syncId'] == 'doc-a', 'Should be User A document');
}
```

---

## Error Messages Reference

### Database Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "Database disk image is malformed" | Database corruption | Backup and recreate database |
| "Database is locked" | Concurrent access | Close other connections, retry |
| "Unable to open database file" | File permissions or disk full | Check permissions and disk space |
| "Database switch already in progress" | Concurrent switch attempt | Wait for current switch to complete |
| "Failed to get user ID" | Authentication issue | Sign out and sign in again |
| "Migration failed" | Disk space or corruption | Check disk space, verify legacy DB |

### File Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "File not found" | Wrong directory or deleted file | Check user directory, verify file path |
| "Permission denied" | File permissions | Ensure file is in app documents directory |
| "No space left on device" | Disk full | Free up disk space |
| "Directory creation failed" | Permissions or disk full | Check permissions and disk space |

### Authentication Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| "User not authenticated" | Not signed in | Sign in before accessing user database |
| "Invalid user ID" | Malformed Cognito sub | Sign out and sign in again |
| "Authentication token expired" | Session expired | Sign in again |

---

## Performance Issues

### Slow Database Operations

**Symptoms:**
- Database queries take several seconds
- App becomes unresponsive during database access
- UI freezes when switching users

**Solutions:**

1. **Vacuum database:**
```dart
await NewDatabaseService.instance.vacuumDatabase();
```

2. **Check database size:**
```dart
final stats = await NewDatabaseService.instance.getDatabaseStats();
print('Database size: ${stats['file_size_mb']} MB');
```

3. **Optimize queries:**
   - Add indexes on frequently queried columns
   - Use transactions for batch operations
   - Limit query results

4. **Clear old logs:**
```dart
await LogService().clearOldLogs(daysToKeep: 7);
```

### Slow Migration

**Symptoms:**
- Migration takes several minutes
- App appears frozen during migration
- Migration timeout errors

**Solutions:**

1. **Check document count:**
```dart
final legacyDb = await openDatabase(legacyPath, readOnly: true);
final count = Sqflite.firstIntValue(
  await legacyDb.rawQuery('SELECT COUNT(*) FROM documents')
);
print('Documents to migrate: $count');
```

2. **Show progress indicator:**
```dart
// Add progress callback to migration
await migrateLegacyDatabase(
  userId,
  onProgress: (current, total) {
    print('Migrating: $current/$total');
  },
);
```

3. **Optimize migration:**
   - Use transactions for batch inserts
   - Increase batch size
   - Run in background isolate

### High Memory Usage

**Symptoms:**
- App crashes with out-of-memory errors
- Device becomes slow when using app
- Memory warnings in logs

**Solutions:**

1. **Close unused databases:**
```dart
await NewDatabaseService.instance.close();
```

2. **Limit query results:**
```dart
// Instead of loading all documents
final allDocs = await db.query('documents');

// Load in batches
final batch1 = await db.query('documents', limit: 100, offset: 0);
final batch2 = await db.query('documents', limit: 100, offset: 100);
```

3. **Clear caches:**
```dart
// Clear image cache
PaintingBinding.instance.imageCache.clear();

// Clear log cache
await LogService().clearLogs();
```

---

## Recovery Procedures

### Recover from Database Corruption

1. **Backup corrupted database:**
```dart
final dbPath = await getDatabasesPath();
final dbFile = File(join(dbPath, 'household_docs_{userId}.db'));
final backupPath = join(dbPath, 'household_docs_{userId}.db.backup');
await dbFile.copy(backupPath);
```

2. **Delete corrupted database:**
```dart
await NewDatabaseService.instance.deleteUserDatabase(userId);
```

3. **Sign out and sign in:**
```dart
await AuthenticationService().signOut();
await AuthenticationService().signIn(email, password);
```

4. **Restore from cloud (if sync enabled):**
   - New database will be created
   - Cloud sync will download documents
   - Local files may need re-download

### Recover from Failed Migration

1. **Clear migration status:**
```dart
final prefs = await SharedPreferences.getInstance();
final migratedUsers = prefs.getStringList('migrated_users') ?? [];
migratedUsers.remove(userId);
await prefs.setStringList('migrated_users', migratedUsers);
```

2. **Verify legacy database exists:**
```dart
final legacyPath = join(await getDatabasesPath(), 'household_docs_v2.db');
final legacyFile = File(legacyPath);
print('Legacy database exists: ${await legacyFile.exists()}');
```

3. **Retry migration:**
```dart
await AuthenticationService().signOut();
await AuthenticationService().signIn(email, password);
// Migration will be attempted again
```

4. **Manual migration (if automatic fails):**
```dart
try {
  await NewDatabaseService.instance.migrateLegacyDatabase(userId);
  print('Manual migration successful');
} catch (e) {
  print('Manual migration failed: $e');
  // Contact support with error details
}
```

### Recover from Wrong Database

If user is seeing wrong data:

1. **Verify current user:**
```dart
final authUserId = await AuthenticationService().getUserId();
final dbUserId = NewDatabaseService.instance._currentUserId;
print('Auth user: $authUserId');
print('DB user: $dbUserId');
```

2. **Force database switch:**
```dart
await NewDatabaseService.instance.close();
final db = await NewDatabaseService.instance.database;
// Will open correct database
```

3. **Verify database contents:**
```dart
final docs = await db.query('documents');
print('Document count: ${docs.length}');
// Verify these are the correct user's documents
```

4. **If still wrong, sign out and sign in:**
```dart
await AuthenticationService().signOut();
await AuthenticationService().signIn(email, password);
```

---

## Prevention Best Practices

### For Developers

1. **Always use database getter:**
```dart
// Good
final db = await NewDatabaseService.instance.database;

// Bad - don't cache database reference
final db = NewDatabaseService.instance._database;
```

2. **Handle errors gracefully:**
```dart
try {
  await db.insert('documents', document.toJson());
} on DatabaseException catch (e) {
  _logService.logError('Insert failed', e, StackTrace.current);
  // Show user-friendly error message
  rethrow;
}
```

3. **Close database on sign out:**
```dart
// In sign-out flow
await NewDatabaseService.instance.close();
await AuthenticationService().signOut();
```

4. **Test with multiple users:**
```dart
// Test data isolation
testWidgets('users have isolated data', (tester) async {
  // Test User A
  await signIn('userA@example.com', 'password');
  await createDocument('User A Doc');
  await signOut();
  
  // Test User B
  await signIn('userB@example.com', 'password');
  final docs = await getDocuments();
  expect(docs, isEmpty); // Should not see User A's docs
});
```

5. **Monitor database operations:**
```dart
// Add logging to track operations
_logService.log('Database operation: $operation', level: LogLevel.debug);
```

### For Users

1. **Sign out properly:**
   - Use the sign-out button in settings
   - Don't force-close the app during sign-out

2. **Wait for operations to complete:**
   - Don't sign out during sync
   - Wait for uploads/downloads to finish

3. **Keep app updated:**
   - Install updates promptly
   - Updates may include database fixes

4. **Report issues:**
   - Use in-app log viewer
   - Export logs when reporting issues
   - Include steps to reproduce

5. **Backup important data:**
   - Enable cloud sync
   - Regularly sync documents
   - Don't rely solely on local storage

---

## Getting Help

### Collect Diagnostic Information

Before contacting support, collect:

1. **App logs:**
   - Settings → View Logs → Export Logs
   - Include last 500 lines

2. **Database information:**
```dart
final stats = await NewDatabaseService.instance.getDatabaseStats();
print('Database stats: $stats');

final databases = await NewDatabaseService.instance.listUserDatabases();
print('All databases: $databases');
```

3. **Device information:**
   - Device model
   - OS version
   - App version
   - Available storage

4. **Steps to reproduce:**
   - What were you doing when the issue occurred?
   - Can you reproduce the issue?
   - Does it happen every time?

### Contact Support

Include in your support request:

- Detailed description of the issue
- Steps to reproduce
- Exported logs
- Database statistics
- Device information
- Screenshots (if applicable)

### Emergency Recovery

If app is completely broken:

1. **Uninstall and reinstall app**
   - ⚠️ This will delete all local data
   - Cloud-synced data will be preserved

2. **Sign in again**
   - Cloud sync will restore documents
   - Local files may need re-download

3. **Contact support**
   - Provide logs before uninstalling (if possible)
   - Explain what happened

---

## Appendix

### Database File Locations

**iOS:**
```
/var/mobile/Containers/Data/Application/{UUID}/Documents/
├── household_docs_guest.db
├── household_docs_{userId1}.db
└── household_docs_{userId2}.db
```

**Android:**
```
/data/data/com.example.household_docs_app/databases/
├── household_docs_guest.db
├── household_docs_{userId1}.db
└── household_docs_{userId2}.db
```

### File Directory Locations

**iOS:**
```
/var/mobile/Containers/Data/Application/{UUID}/Documents/files/
├── guest/
├── {userId1}/
└── {userId2}/
```

**Android:**
```
/data/data/com.example.household_docs_app/files/files/
├── guest/
├── {userId1}/
└── {userId2}/
```

### Useful SQL Queries

**Count documents:**
```sql
SELECT COUNT(*) FROM documents;
```

**List all documents:**
```sql
SELECT syncId, title, createdAt FROM documents ORDER BY createdAt DESC;
```

**Check file attachments:**
```sql
SELECT fa.fileName, fa.localPath, fa.s3Key, d.title
FROM file_attachments fa
JOIN documents d ON fa.documentSyncId = d.syncId;
```

**Database size:**
```sql
SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size();
```

**Vacuum database:**
```sql
VACUUM;
```

---

**Last Updated:** January 30, 2026
**Version:** 1.0.0
