# User-Scoped Database Quick Reference

## Quick Start

### Basic Usage

```dart
// Get current user's database (automatically switches if user changed)
final db = await NewDatabaseService.instance.database;

// Query documents
final documents = await db.query('documents');

// Insert document
await db.insert('documents', document.toJson());

// Update document
await db.update('documents', document.toJson(), 
  where: 'syncId = ?', whereArgs: [syncId]);

// Delete document
await db.delete('documents', 
  where: 'syncId = ?', whereArgs: [syncId]);
```

### Authentication Integration

```dart
// Sign in (automatically initializes user database)
await AuthenticationService().signIn(email, password);

// Sign out (automatically closes database)
await AuthenticationService().signOut();
```

---

## Common Tasks

### Check Migration Status

```dart
final userId = await AuthenticationService().getUserId();
final migrated = await NewDatabaseService.instance.hasBeenMigrated(userId);
print('User migrated: $migrated');
```

### Force Migration

```dart
final userId = await AuthenticationService().getUserId();
await NewDatabaseService.instance.migrateLegacyDatabase(userId);
```

### List All Databases

```dart
final databases = await NewDatabaseService.instance.listUserDatabases();
print('Databases: $databases');
```

### Get Database Statistics

```dart
final stats = await NewDatabaseService.instance.getDatabaseStats();
print('Documents: ${stats['document_count']}');
print('Size: ${stats['file_size_mb']} MB');
print('User: ${stats['user_id']}');
```

### Optimize Database

```dart
await NewDatabaseService.instance.vacuumDatabase();
```

### Delete User Database

```dart
await NewDatabaseService.instance.deleteUserDatabase(userId);
```

---

## File Operations

### Upload File

```dart
// File is automatically stored in user-specific directory
final localPath = await FileService().uploadFile(
  localFilePath: filePath,
  syncId: document.syncId,
  identityPoolId: identityPoolId,
);
```

### Download File

```dart
// File is automatically downloaded to user-specific directory
final localPath = await FileService().downloadFile(
  s3Key: s3Key,
  syncId: document.syncId,
  identityPoolId: identityPoolId,
);
```

### Clear User Files

```dart
await FileService().clearUserFiles();
```

---

## Guest Mode

### Check for Guest Data

```dart
final migrationService = GuestDataMigrationService();
final hasData = await migrationService.hasGuestData();
```

### Migrate Guest Data

```dart
if (hasData) {
  await migrationService.migrateGuestData();
}
```

---

## Error Handling

### Database Errors

```dart
try {
  final db = await NewDatabaseService.instance.database;
  await db.insert('documents', document.toJson());
} on DatabaseException catch (e) {
  if (e.isCorruptionError()) {
    // Handle corruption
  } else if (e.isLockError()) {
    // Retry operation
  } else {
    // Log and rethrow
    LogService().logError('Database error', e, StackTrace.current);
    rethrow;
  }
}
```

### Migration Errors

```dart
try {
  await NewDatabaseService.instance.migrateLegacyDatabase(userId);
} catch (e) {
  LogService().logError('Migration failed', e, StackTrace.current);
  // Migration will be retried on next sign-in
}
```

---

## Best Practices

### ✅ Do

- Always use `NewDatabaseService.instance.database` getter
- Let the service handle database switching automatically
- Close database on sign-out (handled by AuthenticationService)
- Use transactions for batch operations
- Log all database operations
- Handle errors gracefully

### ❌ Don't

- Don't cache database references
- Don't access `_database` directly
- Don't open multiple database connections
- Don't perform long-running operations on main thread
- Don't ignore migration errors
- Don't delete databases without closing them first

---

## Testing

### Mock Database Service

```dart
class MockDatabaseService extends Mock implements NewDatabaseService {}

// In test
final mockDb = MockDatabase();
when(mockDbService.database).thenAnswer((_) async => mockDb);
```

### Test Data Isolation

```dart
testWidgets('users have isolated data', (tester) async {
  // User A
  await signIn('userA@example.com', 'password');
  await createDocument('User A Doc');
  await signOut();
  
  // User B
  await signIn('userB@example.com', 'password');
  final docs = await getDocuments();
  expect(docs, isEmpty); // Should not see User A's docs
});
```

### Test Migration

```dart
test('migration copies all data', () async {
  // Create legacy database with test data
  await createLegacyDatabase(documents: 10, files: 5);
  
  // Sign in (triggers migration)
  await signIn('user@example.com', 'password');
  
  // Verify migration
  final docs = await getDocuments();
  expect(docs.length, 10);
  
  final files = await getFileAttachments();
  expect(files.length, 5);
});
```

---

## Debugging

### Enable Debug Logging

```dart
// In NewDatabaseService
_logService.log('Database operation: $operation', level: LogLevel.debug);
```

### Check Current Database

```dart
print('Current user: ${NewDatabaseService.instance._currentUserId}');
print('Database open: ${NewDatabaseService.instance._database != null}');
```

### Inspect Database File

```dart
final dbPath = await getDatabasesPath();
final dbFile = File(join(dbPath, 'household_docs_{userId}.db'));
print('Database exists: ${await dbFile.exists()}');
print('Database size: ${await dbFile.length()} bytes');
```

---

## Performance Tips

### Minimize Database Switches

```dart
// Good - single database access
final db = await NewDatabaseService.instance.database;
await db.insert('documents', doc1.toJson());
await db.insert('documents', doc2.toJson());

// Bad - multiple database accesses
await (await NewDatabaseService.instance.database).insert('documents', doc1.toJson());
await (await NewDatabaseService.instance.database).insert('documents', doc2.toJson());
```

### Use Transactions

```dart
final db = await NewDatabaseService.instance.database;
await db.transaction((txn) async {
  for (final doc in documents) {
    await txn.insert('documents', doc.toJson());
  }
});
```

### Batch Operations

```dart
final db = await NewDatabaseService.instance.database;
final batch = db.batch();
for (final doc in documents) {
  batch.insert('documents', doc.toJson());
}
await batch.commit();
```

---

## Security Checklist

- [ ] User IDs are validated and sanitized
- [ ] Database files are user-specific
- [ ] File directories are user-specific
- [ ] Database is closed on sign-out
- [ ] No cross-user data access
- [ ] Errors don't leak user information
- [ ] Logs don't contain PII

---

## Migration Checklist

- [ ] Legacy database exists
- [ ] User not already migrated
- [ ] Sufficient disk space
- [ ] Migration logged
- [ ] User marked as migrated
- [ ] Migration idempotent (safe to retry)

---

## Troubleshooting Quick Fixes

### Database Not Switching

```dart
await NewDatabaseService.instance.close();
// Next access will open correct database
```

### Migration Not Occurring

```dart
// Clear migration status
final prefs = await SharedPreferences.getInstance();
final migratedUsers = prefs.getStringList('migrated_users') ?? [];
migratedUsers.remove(userId);
await prefs.setStringList('migrated_users', migratedUsers);

// Sign out and sign in to retry
```

### Database Corruption

```dart
// Backup corrupted database
final dbPath = await getDatabasesPath();
final dbFile = File(join(dbPath, 'household_docs_{userId}.db'));
await dbFile.rename(join(dbPath, 'household_docs_{userId}.db.corrupted'));

// Next access will create new database
```

---

## API Quick Reference

### NewDatabaseService

| Method | Description | Returns |
|--------|-------------|---------|
| `get database` | Get current user's database | `Future<Database>` |
| `close()` | Close current database | `Future<void>` |
| `migrateLegacyDatabase(userId)` | Migrate legacy data | `Future<void>` |
| `hasBeenMigrated(userId)` | Check migration status | `Future<bool>` |
| `listUserDatabases()` | List all databases | `Future<List<String>>` |
| `deleteUserDatabase(userId)` | Delete user's database | `Future<void>` |
| `vacuumDatabase()` | Optimize database | `Future<void>` |
| `getDatabaseStats()` | Get statistics | `Future<Map<String, dynamic>>` |

### AuthenticationService (Modified)

| Method | Description | Returns |
|--------|-------------|---------|
| `signIn(email, password)` | Sign in and init database | `Future<AuthResult>` |
| `signOut()` | Sign out and close database | `Future<void>` |
| `getUserId()` | Get Cognito sub | `Future<String>` |

### FileService (Modified)

| Method | Description | Returns |
|--------|-------------|---------|
| `uploadFile(...)` | Upload to user directory | `Future<String>` |
| `downloadFile(...)` | Download to user directory | `Future<String>` |
| `clearUserFiles()` | Clear user's files | `Future<void>` |

---

## File Locations

### Database Files

```
iOS: /var/mobile/Containers/Data/Application/{UUID}/Documents/
Android: /data/data/{package}/databases/

├── household_docs_guest.db
├── household_docs_{userId1}.db
├── household_docs_{userId2}.db
└── household_docs_v2.db (legacy)
```

### File Directories

```
iOS: /var/mobile/Containers/Data/Application/{UUID}/Documents/files/
Android: /data/data/{package}/files/files/

├── guest/
├── {userId1}/
└── {userId2}/
```

---

## Related Documentation

- [USER_SCOPED_DATABASE.md](USER_SCOPED_DATABASE.md) - Complete documentation
- [USER_SCOPED_DATABASE_TROUBLESHOOTING.md](USER_SCOPED_DATABASE_TROUBLESHOOTING.md) - Troubleshooting guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - Overall architecture

---

**Last Updated:** January 30, 2026
