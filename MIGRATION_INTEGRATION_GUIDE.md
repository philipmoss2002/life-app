# Migration Integration Guide

## Overview

This guide explains how to integrate the User Pool sub-based file migration system with your authentication flow. The migration system automatically detects and migrates existing users from the legacy username-based path structure to the new User Pool sub-based structure.

## Key Components

### 1. PersistentFileService Migration Methods

The `PersistentFileService` provides three key methods for migration:

- **`migrateExistingUser()`** - Main entry point for user migration
- **`needsMigration()`** - Lightweight check if migration is needed
- **`getMigrationStatus()`** - Get detailed migration status

## Integration Approaches

### Approach 1: Automatic Migration on First Login (Recommended)

Integrate migration into your authentication flow to automatically migrate users on their first login after deployment.

```dart
import 'package:household_docs_app/services/persistent_file_service.dart';

class AuthenticationService {
  final PersistentFileService _fileService = PersistentFileService();

  Future<void> onUserSignIn(String userId) async {
    try {
      // Check if user needs migration
      final needsMigration = await _fileService.needsMigration();
      
      if (needsMigration) {
        print('🔄 User has legacy files - starting migration...');
        
        // Perform migration
        final result = await _fileService.migrateExistingUser();
        
        if (result['success'] == true) {
          print('✅ Migration completed successfully');
          print('   Migrated ${result['migratedFiles']} files');
        } else {
          print('⚠️ Migration completed with issues');
          print('   Failed files: ${result['failedFiles']}');
        }
      } else {
        print('✅ No migration needed - user already using new path structure');
      }
    } catch (e) {
      print('❌ Migration check/execution failed: $e');
      // Continue with login - migration can be retried later
    }
  }
}
```

### Approach 2: Background Migration

Perform migration in the background without blocking the user experience.

```dart
class AuthenticationService {
  final PersistentFileService _fileService = PersistentFileService();

  Future<void> onUserSignIn(String userId) async {
    // Check migration need without blocking
    _fileService.needsMigration().then((needsMigration) {
      if (needsMigration) {
        // Perform migration in background
        _performBackgroundMigration();
      }
    });
  }

  Future<void> _performBackgroundMigration() async {
    try {
      print('🔄 Starting background migration...');
      final result = await _fileService.migrateExistingUser();
      
      if (result['success'] == true) {
        print('✅ Background migration completed');
        // Optionally notify user
        _notifyUserMigrationComplete(result);
      }
    } catch (e) {
      print('❌ Background migration failed: $e');
      // Schedule retry
    }
  }

  void _notifyUserMigrationComplete(Map<String, dynamic> result) {
    // Show a non-intrusive notification to user
    // e.g., "Your files have been updated to the new system"
  }
}
```

### Approach 3: Manual Migration Trigger

Provide a manual migration option in settings for users who want control.

```dart
class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PersistentFileService _fileService = PersistentFileService();
  bool _isMigrating = false;
  Map<String, dynamic>? _migrationStatus;

  @override
  void initState() {
    super.initState();
    _checkMigrationStatus();
  }

  Future<void> _checkMigrationStatus() async {
    final status = await _fileService.getMigrationStatus();
    setState(() {
      _migrationStatus = status;
    });
  }

  Future<void> _performMigration() async {
    setState(() {
      _isMigrating = true;
    });

    try {
      final result = await _fileService.migrateExistingUser();
      
      // Show result to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['success'] == true
                ? 'Migration completed: ${result['migratedFiles']} files'
                : 'Migration failed: ${result['error']}',
          ),
        ),
      );

      // Refresh status
      await _checkMigrationStatus();
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_migrationStatus == null) {
      return CircularProgressIndicator();
    }

    final needsMigration = _migrationStatus!['migrationComplete'] != true;

    return ListTile(
      title: Text('File System Migration'),
      subtitle: Text(
        needsMigration
            ? 'Legacy files detected: ${_migrationStatus!['totalLegacyFiles']} files'
            : 'All files migrated',
      ),
      trailing: needsMigration
          ? ElevatedButton(
              onPressed: _isMigrating ? null : _performMigration,
              child: _isMigrating
                  ? CircularProgressIndicator()
                  : Text('Migrate Now'),
            )
          : Icon(Icons.check_circle, color: Colors.green),
    );
  }
}
```

## Migration Result Structure

The `migrateExistingUser()` method returns a map with the following structure:

```dart
{
  'migrationNeeded': bool,        // Whether migration was needed
  'migrationPerformed': bool,     // Whether migration was attempted
  'success': bool,                // Whether migration succeeded
  'totalFiles': int,              // Total legacy files found
  'migratedFiles': int,           // Number of successfully migrated files
  'failedFiles': int,             // Number of files that failed to migrate
  'durationSeconds': int,         // Time taken for migration
  'timestamp': String,            // ISO 8601 timestamp
  'error': String?,               // Error message if migration failed
  'reason': String?,              // Reason if migration not needed
}
```

## Best Practices

### 1. Non-Blocking Migration

Don't block the user's login experience with migration:

```dart
// ✅ Good - Non-blocking
Future<void> onUserSignIn() async {
  // Allow user to proceed
  _navigateToHomeScreen();
  
  // Check and migrate in background
  _checkAndMigrateInBackground();
}

// ❌ Bad - Blocking
Future<void> onUserSignIn() async {
  // User waits for migration to complete
  await _fileService.migrateExistingUser();
  _navigateToHomeScreen();
}
```

### 2. Error Handling

Always handle migration errors gracefully:

```dart
try {
  final result = await _fileService.migrateExistingUser();
  
  if (result['success'] != true) {
    // Log error but don't block user
    print('Migration incomplete: ${result['failedFiles']} files failed');
    
    // Schedule retry
    _scheduleMigrationRetry();
  }
} catch (e) {
  // Log error but allow user to continue
  print('Migration error: $e');
  
  // User can still access files via fallback mechanism
}
```

### 3. Progress Tracking

For large migrations, show progress to users:

```dart
Future<void> _performMigrationWithProgress() async {
  // Get initial status
  final initialStatus = await _fileService.getMigrationStatus();
  final totalFiles = initialStatus['totalLegacyFiles'];
  
  // Start migration
  _fileService.migrateExistingUser();
  
  // Poll for progress
  Timer.periodic(Duration(seconds: 2), (timer) async {
    final progress = await _fileService.getMigrationProgress();
    final migratedFiles = progress['migratedFiles'];
    final percentage = progress['progressPercentage'];
    
    // Update UI
    setState(() {
      _migrationProgress = percentage;
    });
    
    if (progress['migrationComplete'] == true) {
      timer.cancel();
    }
  });
}
```

### 4. Fallback Support

The system automatically falls back to legacy paths if migration hasn't completed:

```dart
// No special handling needed - PersistentFileService handles fallback
final file = await _fileService.downloadFileWithFallback(syncId, fileName);

// This will:
// 1. Try new User Pool sub-based path first
// 2. Fall back to legacy username-based path if needed
// 3. Work seamlessly during migration period
```

## Migration Monitoring

### Check Migration Status

```dart
final status = await _fileService.getMigrationStatus();

print('Total legacy files: ${status['totalLegacyFiles']}');
print('Migrated files: ${status['migratedFiles']}');
print('Pending files: ${status['pendingFiles']}');
print('Migration complete: ${status['migrationComplete']}');
```

### Get Detailed Progress

```dart
final progress = await _fileService.getMigrationProgress();

print('Status: ${progress['status']}');
print('Progress: ${progress['progressPercentage']}%');
print('Can rollback: ${progress['canRollback']}');

// Get per-file details
for (final detail in progress['details']) {
  print('File: ${detail['fileName']}');
  print('Status: ${detail['status']}');
  print('Legacy path: ${detail['legacyPath']}');
  print('New path: ${detail['newPath']}');
}
```

## Rollback Support

If migration causes issues, you can rollback:

```dart
// Rollback all migrations
final rollbackCount = await _fileService.rollbackMigration();
print('Rolled back $rollbackCount files');

// Rollback specific sync ID
final rollbackCount = await _fileService.rollbackMigrationForSyncId(syncId);
print('Rolled back $rollbackCount files for sync ID: $syncId');
```

## Testing Migration

### Test with Mock Users

```dart
// Test migration detection
test('should detect users with legacy files', () async {
  final needsMigration = await _fileService.needsMigration();
  expect(needsMigration, isTrue);
});

// Test migration execution
test('should migrate user files successfully', () async {
  final result = await _fileService.migrateExistingUser();
  expect(result['success'], isTrue);
  expect(result['migratedFiles'], greaterThan(0));
});

// Test fallback during migration
test('should access files during migration', () async {
  final file = await _fileService.downloadFileWithFallback(syncId, fileName);
  expect(file, isNotNull);
});
```

## Deployment Checklist

- [ ] Integrate `needsMigration()` check into authentication flow
- [ ] Implement migration trigger (automatic or manual)
- [ ] Add error handling for migration failures
- [ ] Test migration with existing users
- [ ] Monitor migration progress in production
- [ ] Plan for rollback if needed
- [ ] Document migration status for support team
- [ ] Set up alerts for migration failures

## Support and Troubleshooting

### Common Issues

**Issue: Migration takes too long**
- Solution: Use background migration approach
- Consider migrating in batches by sync ID

**Issue: Some files fail to migrate**
- Solution: Check migration status for failed files
- Fallback mechanism ensures files remain accessible
- Retry migration for failed files

**Issue: User reports missing files**
- Solution: Check if migration is complete
- Verify fallback mechanism is working
- Check security audit log for access issues

### Getting Help

For migration issues, collect this information:

```dart
// Get comprehensive status
final healthStatus = await _fileService.getHealthStatus();
final migrationProgress = await _fileService.getMigrationProgress();
final securityStats = _fileService.getSecurityStats();

print('Health: $healthStatus');
print('Migration: $migrationProgress');
print('Security: $securityStats');
```

## Conclusion

The migration system is designed to be seamless and non-disruptive. By integrating it into your authentication flow and using the fallback mechanisms, users can continue accessing their files throughout the migration process.

For questions or issues, refer to the implementation in `lib/services/persistent_file_service.dart`.
