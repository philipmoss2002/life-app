import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/document.dart';
import 'database_service.dart';
import 'authentication_service.dart';

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

/// Manages cloud storage usage and quota enforcement
class StorageManager {
  static final StorageManager _instance = StorageManager._internal();
  factory StorageManager() => _instance;
  StorageManager._internal();

  // Dependencies
  final DatabaseService _databaseService = DatabaseService.instance;
  final AuthenticationService _authService = AuthenticationService();

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
          try {
            // Try to get file size from S3
            final fileSize =
                await _getS3FileSize(document.id.toString(), filePath);
            totalBytes += fileSize;
          } catch (e) {
            safePrint('Could not get file size for $filePath: $e');
            // If we can't get S3 size, estimate based on local file if available
            totalBytes += _estimateFileSize(filePath);
          }
        }
      }

      _cachedUsedBytes = totalBytes;
      _lastCalculationTime = DateTime.now();

      // Emit storage update event
      _emitStorageUpdate();

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

  /// Clean up deleted files from S3
  Future<void> cleanupDeletedFiles() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        safePrint('User not authenticated, cannot cleanup files');
        return;
      }

      // List all files in user's S3 directory
      final s3Files = await _listUserS3Files(user.id);

      // Get all documents
      final documents = await _databaseService.getAllDocuments();

      // Build set of valid file paths
      final validFilePaths = <String>{};
      for (final document in documents) {
        for (final filePath in document.filePaths) {
          final s3Key = _generateS3Key(document.id.toString(), filePath);
          validFilePaths.add(s3Key);
        }
      }

      // Delete files that are not in any document
      int deletedCount = 0;
      for (final s3File in s3Files) {
        if (!validFilePaths.contains(s3File)) {
          try {
            await Amplify.Storage.remove(path: StoragePath.fromString(s3File))
                .result;
            deletedCount++;
            safePrint('Deleted orphaned file: $s3File');
          } catch (e) {
            safePrint('Error deleting file $s3File: $e');
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

  Future<int> _getS3FileSize(String documentId, String filePath) async {
    try {
      final s3Key = _generateS3Key(documentId, filePath);
      final result = await Amplify.Storage.getProperties(
        path: StoragePath.fromString(s3Key),
      ).result;

      return result.storageItem.size ?? 0;
    } catch (e) {
      safePrint('Error getting S3 file size: $e');
      return 0;
    }
  }

  int _estimateFileSize(String filePath) {
    // Return a conservative estimate if we can't get actual size
    // Average document file size: 500KB
    return 500 * 1024;
  }

  Future<List<String>> _listUserS3Files(String userId) async {
    try {
      final result = await Amplify.Storage.list(
        path: StoragePath.fromString('documents/'),
      ).result;

      return result.items.map((item) => item.path).toList();
    } catch (e) {
      safePrint('Error listing S3 files: $e');
      return [];
    }
  }

  String _generateS3Key(String documentId, String filePath) {
    final fileName = filePath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'documents/$documentId/$timestamp-$fileName';
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

  /// Dispose resources
  Future<void> dispose() async {
    await _storageUpdateController.close();
  }
}
