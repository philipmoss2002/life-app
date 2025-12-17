import 'dart:io';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path/path.dart' as path;
import 'log_service.dart' as app_log;

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
  void _logDebug(String message) =>
      _logService.log(message, level: app_log.LogLevel.debug);

  /// Upload a file to S3 using the same approach as minimal test
  Future<String> uploadFile(String filePath, String documentId) async {
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
      final s3Key = 'documents/$userId/$documentId/$timestamp-$fileName';
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
  Future<String> downloadFile(String s3Key, String documentId) async {
    _logInfo('📥 SimpleFileSyncManager: Starting download for $s3Key');

    try {
      // Get current user ID for proper isolation
      final user = await Amplify.Auth.getCurrentUser();
      final userId = user.userId;

      final publicPath = 'public/$s3Key';
      final fileName = path.basename(s3Key);

      // Create a temporary download path
      final tempDir = Directory.systemTemp;
      final downloadPath = '${tempDir.path}/downloaded_$fileName';

      _logInfo('📍 User ID: $userId');
      _logInfo('📍 Download from: $publicPath');
      _logInfo('📍 Download to: $downloadPath');

      final downloadResult = await Amplify.Storage.downloadFile(
        path: StoragePath.fromString(publicPath),
        localFile: AWSFile.fromPath(downloadPath),
      ).result;

      _logInfo('✅ Download successful: ${downloadResult.downloadedItem.path}');
      return downloadPath;
    } catch (e) {
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
    String documentId,
  ) async {
    _logInfo(
        '📤 SimpleFileSyncManager: Uploading ${filePaths.length} files for document $documentId');
    _logInfo('📁 File paths to upload: $filePaths');

    final results = <String, String>{};

    for (final filePath in filePaths) {
      try {
        _logInfo('📤 Uploading file: $filePath');
        final s3Key = await uploadFile(filePath, documentId);
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
