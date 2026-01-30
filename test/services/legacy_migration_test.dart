import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/new_database_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Legacy Database Migration', () {
    late NewDatabaseService dbService;
    late Directory testDir;

    setUp(() async {
      // Set up test environment
      SharedPreferences.setMockInitialValues({});
      dbService = NewDatabaseService.instance;

      // Create a temporary test directory
      testDir = await Directory.systemTemp.createTemp('migration_test_');
    });

    tearDown(() async {
      // Clean up
      try {
        await dbService.close();
      } catch (e) {
        // Ignore errors during cleanup
      }

      // Delete test directory
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('hasBeenMigrated returns false for new user', () async {
      final userId = 'test-user-123';
      final migrated = await dbService.hasBeenMigrated(userId);
      expect(migrated, false);
    });

    test('hasBeenMigrated returns true after marking as migrated', () async {
      final userId = 'test-user-456';

      // Initially not migrated
      expect(await dbService.hasBeenMigrated(userId), false);

      // Trigger migration (will mark as migrated even if no legacy DB exists)
      await dbService.migrateLegacyDatabase(userId);

      // Now should be marked as migrated
      expect(await dbService.hasBeenMigrated(userId), true);
    });

    test('migrateLegacyDatabase handles missing legacy database gracefully',
        () async {
      final userId = 'test-user-789';

      // Should not throw even if legacy database doesn't exist
      await dbService.migrateLegacyDatabase(userId);

      // Should mark user as migrated
      expect(await dbService.hasBeenMigrated(userId), true);
    });

    test('multiple users can be tracked separately', () async {
      final user1 = 'user-1';
      final user2 = 'user-2';

      // Migrate user 1
      await dbService.migrateLegacyDatabase(user1);

      // User 1 should be migrated, user 2 should not
      expect(await dbService.hasBeenMigrated(user1), true);
      expect(await dbService.hasBeenMigrated(user2), false);

      // Migrate user 2
      await dbService.migrateLegacyDatabase(user2);

      // Both should be migrated now
      expect(await dbService.hasBeenMigrated(user1), true);
      expect(await dbService.hasBeenMigrated(user2), true);
    });
  });
}
