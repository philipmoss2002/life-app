import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import 'database_service.dart';
import 'authentication_service.dart';
import 'analytics_service.dart';
import 'persistent_file_service.dart';

/// Model representing storage information
class StorageInfo {
  final int usedBytes;
  final int quotaBytes;
  final double usagePercentage;
  final bool isNearLimit;
  final bool isOverLimit;

  StorageInfo({
    required this.usedBytes,
    required this.quotaBytes,
  })  : usagePercentage = quotaBytes > 0 ? (usedBytes / quotaBytes) * 100 : 0,
        isNearLimit = quotaBytes > 0 && (usedBytes / quotaBytes) >= 0.9,
        isOverLimit = usedBytes >= quotaBytes;

  String get usedBytesFormatted => _formatBytes(usedBytes);
  String get quotaBytesFormatted => _formatBytes(quotaBytes);

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Manages cloud storage usage and quota enforcement using User Pool sub-based paths
/// Updated to use PersistentFileService for consistent file access across app reinstalls
class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  // Dependencies
  final DatabaseService _databaseService = DatabaseService.instance;
  final AuthenticationService _authService = AuthenticationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final PersistentFileService _persistentFileService = PersistentFileService();

  // Default quota: 5GB for premium users
  static const int _defaultQuotaBytes = 5 * 1024 * 1024 * 1024;

  // Storage state
  int _cachedUsedBytes = 0;
  DateTime? _lastCalculationTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Event streaming
  final StreamController<StorageInfo> _storageUpdateController =
      StreamController<StorageInfo>.broadcast();

  /// Stream of storage updates
  Stream<StorageInfo> get storageUpdates => _storageUpdateController.stream;

  /// Get current storage information
  Future<StorageInfo> getStorageInfo() async {
    // Use cached value if recent
    if (_lastCalculationTime != null &&
        DateTime.now().difference(_lastCalculationTime!) <
            _cacheValidDuration) {
      return StorageInfo(
        usedBytes: _cachedUsedBytes,
        quotaBytes: _defaultQuotaBytes,
      );
    }

    // Recalculate usage
    await calculateUsage();

    return StorageInfo(
      usedBytes: _cachedUsedBytes,
      quotaBytes: _defaultQuotaBytes,
    );
  }

  /// Calculate total storage usage
  Future<void> calculateUsage() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        safePrint('User not authenticated, cannot calculate storage');
        _cachedUsedBytes = 0;
        _lastCalculationTime = DateTime.now();
        return;
      }

      int totalBytes = 0;

      // Get all documents for the user
      final documents = await _databaseService.getAllDocuments();

      // Calculate storage for each document
      for (final document in documents) {
        // Add document metadata size (approximate)
        totalBytes += _estimateDocumentMetadataSize(document);

        // Add file attachment sizes
        for (final filePath in document.filePaths) {
          // TEMPORARILY DISABLED S3 size calculation to avoid NoSuchKey errors
          // Use estimated file sizes instead
          totalBytes += _estimateFileSize(filePath);
          safePrint('Using estimated size for file: $filePath');
        }
      }

      _cachedUsedBytes = totalBytes;
      _lastCalculationTime = DateTime.now();

      // Emit storage update event
      _emitStorageUpdate();

      // Track storage analytics
      final fileCount = documents.fold<int>(
        0,
        (sum, doc) => sum + doc.filePaths.length,
      );

      await _analyticsService.trackStorageUsage(
        usedBytes: totalBytes,
        quotaBytes: _defaultQuotaBytes,
        documentCount: documents.length,
        fileCount: fileCount,
      );

      safePrint('Storage usage calculated: ${_formatBytes(totalBytes)}');
    } catch (e) {
      safePrint('Error calculating storage usage: $e');
      rethrow;
    }
  }

  /// Check if there is available space for a given number of bytes
  Future<bool> hasAvailableSpace(int bytes) async {
    final storageInfo = await getStorageInfo();
    final availableBytes = storageInfo.quotaBytes - storageInfo.usedBytes;
    return availableBytes >= bytes;
  }

  /// Clean up deleted files from S3 using User Pool sub-based paths
  Future<void> cleanupDeletedFiles() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        safePrint('User not authenticated, cannot cleanup files');
        return;
      }

      // List all files in user's S3 directory using User Pool sub-based paths
      final s3Files = await _listUserS3Files();

      // Get all documents
      final documents = await _databaseService.getAllDocuments();

      // Build set of valid file paths
      final validFilePaths = <String>{};
      for (final document in documents) {
        for (final filePath in document.filePaths) {
          // Use PersistentFileService to generate User Pool sub-based S3 key
          final s3Key = await _generateS3Key(document.syncId, filePath);
          validFilePaths.add(s3Key);
        }
      }

      // Delete files that are not in any document
      int deletedCount = 0;
      for (final s3File in s3Files) {
        if (!validFilePaths.contains(s3File)) {
          try {
            // Use PersistentFileService for consistent deletion
            await _persistentFileService.deleteFile(s3File);
            deletedCount++;
            safePrint(
                'Deleted orphaned file using User Pool sub-based access: $s3File');
          } catch (e) {
            // Fallback to direct S3 deletion for legacy compatibility
            try {
              await Amplify.Storage.remove(path: StoragePath.fromString(s3File))
                  .result;
              deletedCount++;
              safePrint(
                  'Deleted orphaned file using direct S3 access: $s3File');
            } catch (directError) {
              safePrint('Error deleting file $s3File: $directError');
            }
          }
        }
      }

      safePrint('Cleanup completed: $deletedCount files deleted');

      // Recalculate usage after cleanup
      await calculateUsage();
    } catch (e) {
      safePrint('Error during cleanup: $e');
      rethrow;
    }
  }

  // Private helper methods

  int _estimateDocumentMetadataSize(Document document) {
    // Estimate metadata size based on field lengths
    int size = 0;
    size += document.title.length * 2; // UTF-16 encoding
    size += document.category.length * 2;
    size += (document.notes?.length ?? 0) * 2;
    size += 100; // Overhead for other fields (dates, IDs, etc.)
    return size;
  }

  int _estimateFileSize(String filePath) {
    // Return a conservative estimate if we can't get actual size
    // Average document file size: 500KB
    return 500 * 1024;
  }

  /// List user's S3 files using User Pool sub-based private access
  /// Uses PersistentFileService for consistent file listing
  Future<List<String>> _listUserS3Files() async {
    try {
      // Check if user is authenticated using PersistentFileService
      if (!await _persistentFileService.isUserAuthenticated()) {
        throw Exception('User not authenticated');
      }

      // Get User Pool sub for listing user's files
      final userSub = await _persistentFileService.getUserPoolSub();

      // List files in user's private folder using User Pool sub
      // Private access level format: private/{userSub}/documents/
      final result = await Amplify.Storage.list(
        path: StoragePath.fromString('private/$userSub/documents/'),
      ).result;

      final userFiles = result.items.map((item) => item.path).toList();
      safePrint(
          'Listed ${userFiles.length} files using User Pool sub-based private access');

      return userFiles;
    } catch (e) {
      // Fallback to legacy username-based listing for backward compatibility
      safePrint('User Pool sub-based listing failed, trying legacy method: $e');

      try {
        // Get Cognito username for listing user's files (legacy)
        final user = await Amplify.Auth.getCurrentUser();
        final username = user.username;

        if (username.isEmpty) {
          throw Exception(
              'No Cognito username available - user may not be properly authenticated');
        }

        // List files in user's protected folder using username (legacy)
        final result = await Amplify.Storage.list(
          path: StoragePath.fromString('protected/$username/documents/'),
        ).result;

        final legacyFiles = result.items.map((item) => item.path).toList();
        safePrint(
            'Listed ${legacyFiles.length} files using legacy username-based access');

        return legacyFiles;
      } catch (legacyError) {
        // If we can't list S3 files, return empty list to avoid blocking sync
        safePrint(
            'Error listing S3 files (continuing without cleanup): $legacyError');
        return [];
      }
    }
  }

  /// Generate S3 key using User Pool sub-based private access
  /// Uses PersistentFileService for consistent path generation
  Future<String> _generateS3Key(String syncId, String filePath) async {
    try {
      // Extract filename from file path
      final fileName = filePath.split('/').last;

      // Use PersistentFileService to generate User Pool sub-based S3 key
      return await _persistentFileService.generateS3Path(syncId, fileName);
    } catch (e) {
      safePrint(
          'PersistentFileService S3 key generation failed, falling back to legacy method: $e');

      // Fallback to legacy username-based path generation for compatibility
      final user = await Amplify.Auth.getCurrentUser();
      final username = user.username;

      if (username.isEmpty) {
        throw Exception(
            'No Cognito username available - user may not be properly authenticated');
      }

      final fileName = filePath.split('/').last;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Use syncId for consistency with SimpleFileSyncManager and FileSyncManager
      // Username-based paths provide consistent access across app reinstalls (legacy)
      return 'protected/$username/documents/$syncId/$timestamp-$fileName';
    }
  }

  String _formatBytes(int bytes) {
    return StorageInfo._formatBytes(bytes);
  }

  void _emitStorageUpdate() {
    if (!_storageUpdateController.isClosed) {
      _storageUpdateController.add(StorageInfo(
        usedBytes: _cachedUsedBytes,
        quotaBytes: _defaultQuotaBytes,
      ));
    }
  }

  /// Invalidate cache to force recalculation on next getStorageInfo call
  void invalidateCache() {
    _lastCalculationTime = null;
  }

  /// Clear user-specific storage data for user isolation
  /// Called when user signs out to prevent storage data leakage between users
  Future<void> clearUserStorageData() async {
    try {
      // Clear cached storage data
      _cachedUsedBytes = 0;
      _lastCalculationTime = null;

      // Emit storage update with cleared data
      _emitStorageUpdate();

      safePrint(
          'StorageManager: User-specific data cleared for user isolation');
    } catch (e) {
      safePrint('Error clearing user storage data: $e');
    }
  }

  /// Reset storage manager for new user session
  /// Called when a new user signs in to ensure clean storage state
  Future<void> resetForNewUser() async {
    await clearUserStorageData();
    safePrint('StorageManager: Reset for new user session');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _storageUpdateController.close();
  }

  /// Get User Pool sub for debugging purposes
  /// Uses PersistentFileService for consistent user identification
  Future<String> getUserPoolSub() async {
    try {
      return await _persistentFileService.getUserPoolSub();
    } catch (e) {
      safePrint('Error getting User Pool sub: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  /// Uses PersistentFileService for consistent authentication checking
  Future<bool> isUserAuthenticated() async {
    try {
      return await _persistentFileService.isUserAuthenticated();
    } catch (e) {
      safePrint('Error checking user authentication: $e');
      return false;
    }
  }

  /// Check if a file exists using User Pool sub-based paths with fallback
  /// Uses PersistentFileService for consistent file checking
  Future<bool> fileExists(String syncId, String fileName) async {
    try {
      return await _persistentFileService.fileExistsWithFallback(
          syncId, fileName);
    } catch (e) {
      safePrint('Error checking file existence: $e');
      return false;
    }
  }
}
