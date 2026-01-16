import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

/// Service for managing app data cleanup and ensuring proper data removal
class DataCleanupService {
  static final DataCleanupService _instance = DataCleanupService._internal();
  factory DataCleanupService() => _instance;
  DataCleanupService._internal();

  /// Clear all app data (for complete reset or uninstall preparation)
  Future<void> clearAllAppData() async {
    try {
      debugPrint('🧹 Starting complete app data cleanup...');

      // Clear database
      await DatabaseService.instance.clearAllData();
      debugPrint('✅ Database cleared');

      // Clear file cache
      await _clearFileCache();
      debugPrint('✅ File cache cleared');

      // Clear thumbnails
      await _clearThumbnailCache();
      debugPrint('✅ Thumbnail cache cleared');

      // Clear temporary files
      await _clearTempFiles();
      debugPrint('✅ Temporary files cleared');

      // Clear app support directory cache
      await _clearAppSupportCache();
      debugPrint('✅ App support cache cleared');

      debugPrint('🎉 All app data cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing app data: $e');
      rethrow;
    }
  }

  /// Clear user-specific data (for sign out)
  Future<void> clearUserData(String userId) async {
    try {
      debugPrint('🧹 Starting user data cleanup for: $userId');

      // Clear user documents from database
      await DatabaseService.instance.clearUserData(userId);
      debugPrint('✅ User database data cleared');

      // Clear user-specific cache files
      await _clearUserCache(userId);
      debugPrint('✅ User cache cleared');

      debugPrint('🎉 User data cleared for: $userId');
    } catch (e) {
      debugPrint('❌ Error clearing user data: $e');
      rethrow;
    }
  }

  /// Clear only cache files (keep database)
  Future<void> clearCacheOnly() async {
    try {
      debugPrint('🧹 Starting cache cleanup...');

      await _clearFileCache();
      await _clearThumbnailCache();
      await _clearTempFiles();

      debugPrint('🎉 Cache cleared successfully');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
      rethrow;
    }
  }

  /// Get total cache size in bytes
  Future<int> getCacheSize() async {
    try {
      int totalSize = 0;

      // Get file cache size
      totalSize += await _getDirectorySize(await _getFileCacheDir());

      // Get thumbnail cache size
      totalSize += await _getDirectorySize(await _getThumbnailCacheDir());

      // Get temp files size
      totalSize += await _getDirectorySize(await _getTempFilesDir());

      return totalSize;
    } catch (e) {
      debugPrint('Error calculating cache size: $e');
      return 0;
    }
  }

  /// Format bytes to human readable string
  String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  // Private helper methods

  Future<void> _clearFileCache() async {
    try {
      final cacheDir = await _getFileCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing file cache: $e');
    }
  }

  Future<void> _clearThumbnailCache() async {
    try {
      final thumbnailDir = await _getThumbnailCacheDir();
      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing thumbnail cache: $e');
    }
  }

  Future<void> _clearTempFiles() async {
    try {
      final tempDir = await _getTempFilesDir();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing temp files: $e');
    }
  }

  Future<void> _clearAppSupportCache() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final cacheDir = Directory('${appDir.path}/cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing app support cache: $e');
    }
  }

  Future<void> _clearUserCache(String userId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final userCacheDir = Directory('${tempDir.path}/app_cache/user_$userId');

      if (await userCacheDir.exists()) {
        await userCacheDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Error clearing user cache: $e');
    }
  }

  Future<Directory> _getFileCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/app_cache');
  }

  Future<Directory> _getThumbnailCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/app_thumbnails');
  }

  Future<Directory> _getTempFilesDir() async {
    final tempDir = await getTemporaryDirectory();
    return Directory('${tempDir.path}/app_temp');
  }

  Future<int> _getDirectorySize(Directory directory) async {
    try {
      if (!await directory.exists()) {
        return 0;
      }

      int size = 0;
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      return size;
    } catch (e) {
      debugPrint('Error calculating directory size: $e');
      return 0;
    }
  }

  /// Clean up old cache files (older than specified days)
  Future<void> cleanupOldCache({int maxAgeDays = 7}) async {
    try {
      debugPrint('🧹 Cleaning up cache files older than $maxAgeDays days...');

      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));

      await _cleanupOldFilesInDirectory(await _getFileCacheDir(), cutoffDate);
      await _cleanupOldFilesInDirectory(
          await _getThumbnailCacheDir(), cutoffDate);
      await _cleanupOldFilesInDirectory(await _getTempFilesDir(), cutoffDate);

      debugPrint('🎉 Old cache cleanup completed');
    } catch (e) {
      debugPrint('❌ Error during old cache cleanup: $e');
    }
  }

  Future<void> _cleanupOldFilesInDirectory(
      Directory directory, DateTime cutoffDate) async {
    try {
      if (!await directory.exists()) {
        return;
      }

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            debugPrint('🗑️ Deleted old cache file: ${entity.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up old files in directory: $e');
    }
  }

  /// Initialize cleanup service (run on app start)
  Future<void> initialize() async {
    try {
      // Clean up old cache files on app start
      await cleanupOldCache();

      debugPrint('🎉 DataCleanupService initialized');
    } catch (e) {
      debugPrint('❌ Error initializing DataCleanupService: $e');
    }
  }
}
