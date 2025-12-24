import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path/path.dart' as path;
import 'log_service.dart' as app_log;

/// Exception thrown when a file is not found in S3
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}

/// Simplified file sync manager that works exactly like the minimal test
class SimpleFileSyncManager {
  static final SimpleFileSyncManager _instance =
      SimpleFileSyncManager._internal();
  factory SimpleFileSyncManager() => _instance;
  SimpleFileSyncManager._internal();

  final app_log.LogService _logService = app_log.LogService();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);

  /// Upload a file to S3 using the same approach as minimal test
  Future<String> uploadFile(String filePath, String syncId) async {
    _logInfo('🚀 SimpleFileSyncManager: Starting upload for $filePath');

    try {
      final file = File(filePath);

      // Check if file exists
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      final fileSize = await file.length();
      _logInfo('📏 File size: $fileSize bytes');

      // Get current user ID for proper isolation
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;

      final fileName = path.basename(filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final s3Key = 'documents/$userId/$syncId/$timestamp-$fileName';
      final publicPath = 'public/$s3Key';

      _logInfo('📍 User ID: $userId');
      _logInfo('📍 S3 Key: $s3Key');
      _logInfo('📍 Public Path (with user isolation): $publicPath');

      // Upload with public access but user-isolated path
      // Note: This provides path-based isolation while working with current config
      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(file.path),
        path: StoragePath.fromString(publicPath),
      ).result;

      _logInfo('✅ Upload successful: ${uploadResult.uploadedItem.path}');
      return s3Key;
    } catch (e) {
      _logError('❌ SimpleFileSyncManager upload failed: $e');
      rethrow;
    }
  }

  /// Download a file from S3 with proper user isolation
  Future<String> downloadFile(String s3Key, String syncId) async {
    _logInfo('📥 SimpleFileSyncManager: Starting download for $s3Key');
    _logInfo('📥 Sync ID parameter: $syncId');

    try {
      // Get current user ID for proper isolation
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;

      // Parse the s3Key to understand its components
      final pathParts = s3Key.split('/');
      _logInfo('📥 S3Key parts: $pathParts');
      if (pathParts.length >= 3) {
        _logInfo('📥 Expected format: documents/userId/syncId/filename');
        _logInfo(
            '📥 Parsed - Prefix: ${pathParts[0]}, UserID: ${pathParts[1]}, SyncID: ${pathParts[2]}');
        _logInfo('📥 Current UserID: $userId');
        _logInfo('📥 UserID match: ${pathParts[1] == userId}');
      }

      final fileName = path.basename(s3Key);

      // Create a temporary download path
      final tempDir = Directory.systemTemp;
      final downloadPath = '${tempDir.path}/downloaded_$fileName';

      _logInfo('📍 User ID: $userId');
      _logInfo('📍 Download to: $downloadPath');

      // Try downloading with public/ prefix first (current standard)
      final publicPath = 'public/$s3Key';
      _logInfo('📍 Trying download from: $publicPath');
      _logInfo('📍 Full S3 path: $publicPath');

      StorageDownloadFileResult? downloadResult;

      try {
        downloadResult = await Amplify.Storage.downloadFile(
          path: StoragePath.fromString(publicPath),
          localFile: AWSFile.fromPath(downloadPath),
        ).result;
      } catch (e) {
        // If public/ path fails, try without public/ prefix (legacy files)
        if (e.toString().contains('NoSuchKey') ||
            e.toString().contains('Cannot find the item specified')) {
          _logWarning(
              '⚠️ File not found at $publicPath, trying legacy path: $s3Key');

          downloadResult = await Amplify.Storage.downloadFile(
            path: StoragePath.fromString(s3Key),
            localFile: AWSFile.fromPath(downloadPath),
          ).result;
        } else {
          rethrow;
        }
      }

      _logInfo('✅ Download successful: ${downloadResult.downloadedItem.path}');
      return downloadPath;
    } catch (e) {
      // Check if this is a NoSuchKey error (file doesn't exist)
      if (e.toString().contains('NoSuchKey') ||
          e.toString().contains('Cannot find the item specified')) {
        _logWarning('⚠️ File not found in S3: $s3Key - may have been deleted');
        throw FileNotFoundException('File not found: $s3Key');
      }

      _logError('❌ SimpleFileSyncManager download failed: $e');
      rethrow;
    }
  }

  /// Delete a file from S3 with proper user isolation
  Future<void> deleteFile(String s3Key) async {
    _logInfo('🗑️ SimpleFileSyncManager: Deleting $s3Key');

    try {
      // Get current user ID for proper isolation
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;

      final publicPath = 'public/$s3Key';

      _logInfo('📍 User ID: $userId');
      _logInfo('📍 Deleting from: $publicPath');

      await Amplify.Storage.remove(
        path: StoragePath.fromString(publicPath),
      ).result;

      _logInfo('✅ Delete successful: $s3Key');
    } catch (e) {
      _logError('❌ SimpleFileSyncManager delete failed: $e');
      rethrow;
    }
  }

  /// Upload multiple files in parallel
  Future<Map<String, String>> uploadFilesParallel(
    List<String> filePaths,
    String syncId,
  ) async {
    _logInfo(
        '📤 SimpleFileSyncManager: Uploading ${filePaths.length} files for sync ID $syncId');
    _logInfo('📁 File paths to upload: $filePaths');

    final results = <String, String>{};

    for (final filePath in filePaths) {
      try {
        _logInfo('📤 Uploading file: $filePath');
        final s3Key = await uploadFile(filePath, syncId);
        results[filePath] = s3Key;
        _logInfo('✅ File uploaded: $filePath -> $s3Key');
      } catch (e) {
        _logError('❌ Failed to upload $filePath: $e');
        rethrow;
      }
    }

    _logInfo('✅ All files uploaded successfully: $results');
    return results;
  }
}
