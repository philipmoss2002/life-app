# Database Migration to Version 2

**Date**: January 18, 2026  
**Migration**: v1 → v2  
**Purpose**: Add category and date fields to documents table

## What Changed

### Database Version
- **Old Version**: 1
- **New Version**: 2

### Schema Changes

#### Documents Table
**Added Columns**:
- `category TEXT NOT NULL DEFAULT 'other'` - Document category (required)
- `date INTEGER` - Optional date field (stored as milliseconds since epoch)

**Renamed Columns** (if applicable):
- `description` → `notes` (from very old schema)

## Migration Behavior

### For New Installations
- Clean database created with version 2 schema
- All columns present from the start
- No migration needed

### For Existing Installations
- Database automatically upgraded from v1 to v2
- Migration runs on first app launch after update
- Existing documents get default category: `other`
- Existing documents have null date (can be set later)

## Migration Process

The migration happens automatically when you:
1. Update the app
2. Launch the app for the first time after update
3. Database service detects old version (v1)
4. Runs `_upgradeDB` function
5. Adds new columns with defaults
6. Updates version to 2

### Migration SQL
```sql
-- Add category column with default value
ALTER TABLE documents ADD COLUMN category TEXT NOT NULL DEFAULT 'other';

-- Add date column (nullable)
ALTER TABLE documents ADD COLUMN date INTEGER;

-- Rename description to notes (if exists from very old schema)
ALTER TABLE documents RENAME COLUMN description TO notes;
```

## User Impact

### Existing Documents
- All existing documents will have category set to "Other"
- Users can edit documents to set correct category
- Date field will be empty (can be set if needed)

### Data Preservation
- ✅ All existing document data preserved
- ✅ All file attachments preserved
- ✅ All sync states preserved
- ✅ No data loss

## Testing the Migration

### Before Migration
```dart
// Old document structure (v1)
{
  'sync_id': 'uuid',
  'title': 'My Document',
  'notes': 'Some notes',
  'labels': '["label1"]',
  'created_at': 1234567890,
  'updated_at': 1234567890,
  'sync_state': 'synced'
  // No category field
  // No date field
}
```

### After Migration
```dart
// New document structure (v2)
{
  'sync_id': 'uuid',
  'title': 'My Document',
  'category': 'other',  // ← Added with default
  'date': null,         // ← Added as nullable
  'notes': 'Some notes',
  'labels': '["label1"]',
  'created_at': 1234567890,
  'updated_at': 1234567890,
  'sync_state': 'synced'
}
```

## Troubleshooting

### Issue: "SQL error: no such column: category"

**Cause**: Database version not updated, migration didn't run

**Solution**:
```dart
// Option 1: Clear app data (loses local documents)
// Settings → Apps → Household Docs → Clear Data

// Option 2: Uninstall and reinstall app
// This will create fresh v2 database

// Option 3: Force database recreation (for development)
final dbService = NewDatabaseService.instance;
await dbService.close();
// Delete database file manually
// Restart app
```

### Issue: Migration fails with error

**Cause**: Database corruption or unexpected schema

**Solution**:
```dart
// Check database version
final db = await NewDatabaseService.instance.database;
final version = await db.getVersion();
print('Current database version: $version');

// If version is wrong, force recreation
await dbService.close();
// Delete: household_docs_v2.db
// Restart app
```

### Issue: Existing documents show "Other" category

**Expected Behavior**: This is correct!

**Explanation**: 
- Migration sets all existing documents to "Other" category
- Users should edit documents to set correct category
- This is safer than trying to guess categories

**User Action Required**:
- Open each document
- Tap Edit
- Select correct category
- Save

## Development Notes

### Testing Migration Locally

1. **Create v1 database**:
```dart
// Temporarily change version back to 1
version: 1,
// Remove category and date columns from CREATE TABLE
// Run app, create some documents
```

2. **Test migration**:
```dart
// Change version to 2
version: 2,
// Add onUpgrade handler
// Run app - migration should execute
// Check logs for migration messages
```

3. **Verify migration**:
```dart
// Check documents have category and date columns
final docs = await repository.getAllDocuments();
for (final doc in docs) {
  print('Category: ${doc.category}'); // Should be 'other'
  print('Date: ${doc.date}');         // Should be null
}
```

### Migration Logs

Look for these debug messages:
```
🔄 Upgrading database from version 1 to 2
📝 Adding category and date columns to documents table
✅ Database upgraded to version 2
```

Or for new installations:
```
✅ Database schema created successfully
```

## Rollback Plan

If migration causes issues:

### Option 1: Rollback Code
```dart
// Revert to version 1
version: 1,
// Remove onUpgrade handler
// Remove category and date from schema
```

### Option 2: Clear Database
```dart
// For development/testing
await dbService.clearAllData();
await dbService.close();
// Delete database file
// Restart app
```

### Option 3: Backup and Restore
```dart
// Before migration (for production)
// 1. Export all documents to JSON
// 2. Run migration
// 3. If issues, restore from JSON
```

## Best Practices

### For Users
1. **Backup before updating** (if possible)
2. **Update during low-usage time**
3. **Verify documents after update**
4. **Recategorize documents as needed**

### For Developers
1. **Test migration thoroughly**
2. **Provide clear migration logs**
3. **Handle migration errors gracefully**
4. **Document breaking changes**
5. **Provide rollback option**

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1 | 2026-01-15 | Initial v2 schema (clean rewrite) |
| 2 | 2026-01-18 | Added category and date fields |

## Next Migration

When planning v3:
- Increment version to 3
- Add new `onUpgrade` case for v2 → v3
- Keep existing v1 → v2 migration
- Test all migration paths

```dart
Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    // v1 → v2 migration (keep this)
    // ...
  }
  
  if (oldVersion < 3) {
    // v2 → v3 migration (add new changes)
    // ...
  }
}
```

## Support

If you encounter migration issues:
1. Check debug logs for migration messages
2. Verify database version
3. Try clearing app data (loses local documents)
4. Report issue with logs and error messages
