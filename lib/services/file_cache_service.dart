import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service for managing file caching using temporary storage
/// This ensures all cached files are removed when the app is uninstalled
class FileCacheService {
  static final FileCacheService _instance = FileCacheService._internal();
  factory FileCacheService() => _instance;
  FileCacheService._internal();

  /// Get local cache path for a file (uses temporary directory)
  Future<String> getLocalCachePath(String s3Key, String syncId) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = path.basename(s3Key);
    final localDir = Directory('${tempDir.path}/app_cache/$syncId');

    // Ensure directory exists
    if (!await localDir.exists()) {
      await localDir.create(recursive: true);
    }

    return '${localDir.path}/$fileName';
  }

  /// Cache a thumbnail (uses temporary directory)
  Future<String?> cacheThumbnail(String s3Key, List<int> thumbnailBytes) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailDir = Directory('${tempDir.path}/app_thumbnails');

      // Ensure directory exists
      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      final thumbnailFileName = s3Key.replaceAll('/', '_') + '_thumb.jpg';
      final thumbnailPath = '${thumbnailDir.path}/$thumbnailFileName';

      await File(thumbnailPath).writeAsBytes(thumbnailBytes);
      debugPrint('📸 Thumbnail cached: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      debugPrint('❌ Error caching thumbnail: $e');
      return null;
    }
  }

  /// Get cached thumbnail path
  Future<String?> getCachedThumbnail(String s3Key) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailFileName = s3Key.replaceAll('/', '_') + '_thumb.jpg';
      final thumbnailPath = '${tempDir.path}/app_thumbnails/$thumbnailFileName';

      final file = File(thumbnailPath);
      if (await file.exists()) {
        return thumbnailPath;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached thumbnail: $e');
      return null;
    }
  }

  /// Clear thumbnail cache
  Future<void> clearThumbnailCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailDir = Directory('${tempDir.path}/app_thumbnails');

      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
        debugPrint('🧹 Thumbnail cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing thumbnail cache: $e');
    }
  }

  /// Clear file cache
  Future<void> clearFileCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory('${tempDir.path}/app_cache');

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        debugPrint('🧹 File cache cleared');
      }
    } catch (e) {
      debugPrint('❌ Error clearing file cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      int totalSize = 0;
      final tempDir = await getTemporaryDirectory();

      // Calculate thumbnail cache size
      final thumbnailDir = Directory('${tempDir.path}/app_thumbnails');
      if (await thumbnailDir.exists()) {
        totalSize += await _getDirectorySize(thumbnailDir);
      }

      // Calculate file cache size
      final cacheDir = Directory('${tempDir.path}/app_cache');
      if (await cacheDir.exists()) {
        totalSize += await _getDirectorySize(cacheDir);
      }

      return totalSize;
    } catch (e) {
      debugPrint('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  /// Create temporary file for processing
  Future<String> createTempFile(String fileName) async {
    final tempDir = await getTemporaryDirectory();
    final appTempDir = Directory('${tempDir.path}/app_temp');

    // Ensure directory exists
    if (!await appTempDir.exists()) {
      await appTempDir.create(recursive: true);
    }

    return '${appTempDir.path}/$fileName';
  }

  /// Clean up old cache files (older than specified days)
  Future<void> cleanupOldCache({int maxAgeDays = 7}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));
      final tempDir = await getTemporaryDirectory();

      // Clean thumbnails
      final thumbnailDir = Directory('${tempDir.path}/app_thumbnails');
      await _cleanupOldFilesInDirectory(thumbnailDir, cutoffDate);

      // Clean file cache
      final cacheDir = Directory('${tempDir.path}/app_cache');
      await _cleanupOldFilesInDirectory(cacheDir, cutoffDate);

      // Clean temp files
      final tempFilesDir = Directory('${tempDir.path}/app_temp');
      await _cleanupOldFilesInDirectory(tempFilesDir, cutoffDate);

      debugPrint('🧹 Old cache files cleaned up');
    } catch (e) {
      debugPrint('❌ Error cleaning up old cache: $e');
    }
  }

  // Private helper methods

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
      debugPrint('❌ Error calculating directory size: $e');
      return 0;
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
      debugPrint('❌ Error cleaning up old files: $e');
    }
  }
}
