import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path/path.dart' as path;
import 'log_service.dart' as app_log;
import 'persistent_file_service.dart';

/// Exception thrown when a file is not found in S3
class FileNotFoundException implements Exception {
  final String message;
  FileNotFoundException(this.message);

  @override
  String toString() => 'FileNotFoundException: $message';
}

/// Simplified file sync manager that uses User Pool sub-based paths
/// Updated to use PersistentFileService for consistent file access across app reinstalls
class SimpleFileSyncManager {
  static final SimpleFileSyncManager _instance =
      SimpleFileSyncManager._internal();
  factory SimpleFileSyncManager() => _instance;
  SimpleFileSyncManager._internal();

  final app_log.LogService _logService = app_log.LogService();
  final PersistentFileService _persistentFileService = PersistentFileService();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);

  /// Upload a file to S3 using User Pool sub-based private access
  /// Uses PersistentFileService for consistent file paths across app reinstalls
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

      // Use PersistentFileService for User Pool sub-based upload
      final s3Key = await _persistentFileService.uploadFile(filePath, syncId);

      _logInfo('✅ Upload successful using User Pool sub-based path: $s3Key');
      _logInfo('📍 Private access - user isolation via User Pool sub');

      return s3Key;
    } catch (e) {
      _logError('❌ SimpleFileSyncManager upload failed: $e');
      rethrow;
    }
  }

  /// Download a file from S3 using User Pool sub-based private access
  /// Uses PersistentFileService with fallback to legacy paths for backward compatibility
  Future<String> downloadFile(String s3Key, String syncId) async {
    _logInfo('📥 SimpleFileSyncManager: Starting download for $s3Key');
    _logInfo('📥 Sync ID parameter: $syncId');

    try {
      // Parse the s3Key to understand its components
      final pathParts = s3Key.split('/');
      _logInfo('📥 S3Key parts: $pathParts');

      // Extract filename from S3 key
      final fileName = path.basename(s3Key);

      // Try to use PersistentFileService for download with fallback
      try {
        // First try direct download if this is already a User Pool sub-based path
        if (s3Key.startsWith('private/')) {
          _logInfo('📥 Downloading from User Pool sub-based path: $s3Key');
          final downloadPath =
              await _persistentFileService.downloadFile(s3Key, syncId);
          _logInfo('✅ Download successful using User Pool sub-based path');
          return downloadPath;
        } else {
          // This is likely a legacy path, try fallback download
          _logInfo('📥 Attempting fallback download for legacy path: $s3Key');
          final downloadPath = await _persistentFileService
              .downloadFileWithFallback(syncId, fileName);
          _logInfo('✅ Download successful using fallback mechanism');
          return downloadPath;
        }
      } catch (e) {
        // If PersistentFileService fails, fall back to direct S3 access for legacy compatibility
        _logWarning(
            '⚠️ PersistentFileService download failed, trying direct S3 access: $e');

        // Create a temporary download path
        final tempDir = Directory.systemTemp;
        final downloadPath = '${tempDir.path}/downloaded_$fileName';

        try {
          // Download directly from S3 using the provided S3 key
          final downloadResult = await Amplify.Storage.downloadFile(
            path: StoragePath.fromString(s3Key),
            localFile: AWSFile.fromPath(downloadPath),
          ).result;

          _logInfo(
              '✅ Direct S3 download successful: ${downloadResult.downloadedItem.path}');
          return downloadPath;
        } catch (directError) {
          if (directError.toString().contains('NoSuchKey') ||
              directError
                  .toString()
                  .contains('Cannot find the item specified')) {
            _logWarning('⚠️ File not found at $s3Key');
            throw FileNotFoundException('File not found: $s3Key');
          } else {
            rethrow;
          }
        }
      }
    } catch (e) {
      // Check if this is a NoSuchKey error (file doesn't exist)
      if (e.toString().contains('NoSuchKey') ||
          e.toString().contains('Cannot find the item specified') ||
          e is FileNotFoundException) {
        _logWarning('⚠️ File not found in S3: $s3Key - may have been deleted');
        throw FileNotFoundException('File not found: $s3Key');
      }

      _logError('❌ SimpleFileSyncManager download failed: $e');
      rethrow;
    }
  }

  /// Delete a file from S3 using User Pool sub-based private access
  /// Uses PersistentFileService for consistent file operations
  Future<void> deleteFile(String s3Key) async {
    _logInfo('🗑️ SimpleFileSyncManager: Deleting $s3Key');

    try {
      // Use PersistentFileService for User Pool sub-based deletion
      await _persistentFileService.deleteFile(s3Key);

      _logInfo('✅ Delete successful using User Pool sub-based access: $s3Key');
      _logInfo('📍 Private access - user isolation via User Pool sub');
    } catch (e) {
      // If PersistentFileService fails, try direct S3 deletion for legacy compatibility
      _logWarning(
          '⚠️ PersistentFileService delete failed, trying direct S3 access: $e');

      try {
        await Amplify.Storage.remove(
          path: StoragePath.fromString(s3Key),
        ).result;

        _logInfo('✅ Direct S3 delete successful: $s3Key');
      } catch (directError) {
        _logError('❌ SimpleFileSyncManager delete failed: $directError');
        rethrow;
      }
    }
  }

  /// Upload multiple files in parallel using User Pool sub-based paths
  /// Uses PersistentFileService for consistent file operations
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

    _logInfo(
        '✅ All files uploaded successfully using User Pool sub-based paths: $results');
    return results;
  }

  /// Check if a file exists using User Pool sub-based paths with fallback
  /// Uses PersistentFileService for consistent file checking
  Future<bool> fileExists(String syncId, String fileName) async {
    _logInfo(
        '🔍 SimpleFileSyncManager: Checking file existence - syncId: $syncId, fileName: $fileName');

    try {
      final exists =
          await _persistentFileService.fileExistsWithFallback(syncId, fileName);
      _logInfo('📋 File existence check result: $exists');
      return exists;
    } catch (e) {
      _logError('❌ Error checking file existence: $e');
      return false;
    }
  }

  /// Get User Pool sub for debugging purposes
  /// Uses PersistentFileService for consistent user identification
  Future<String> getUserPoolSub() async {
    try {
      return await _persistentFileService.getUserPoolSub();
    } catch (e) {
      _logError('❌ Error getting User Pool sub: $e');
      rethrow;
    }
  }

  /// Check if user is authenticated
  /// Uses PersistentFileService for consistent authentication checking
  Future<bool> isUserAuthenticated() async {
    try {
      return await _persistentFileService.isUserAuthenticated();
    } catch (e) {
      _logError('❌ Error checking user authentication: $e');
      return false;
    }
  }
}
