import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'database_service.dart';
import 'persistent_file_service.dart';
import '../models/FileAttachment.dart';
import 'log_service.dart' as app_log;
import 'sync_identifier_service.dart';

/// File manager that uses sync identifiers and User Pool sub-based paths for all operations
/// Updated to use PersistentFileService for consistent file access across app reinstalls
class SyncAwareFileManager {
  static final SyncAwareFileManager _instance =
      SyncAwareFileManager._internal();
  factory SyncAwareFileManager() => _instance;
  SyncAwareFileManager._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final PersistentFileService _persistentFileService = PersistentFileService();

  final app_log.LogService _logService = app_log.LogService();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);

  /// Upload a file and associate it with a document using sync identifier
  /// Uses User Pool sub-based paths for consistent file access via PersistentFileService
  Future<FileAttachment> uploadFileForDocument(String filePath, String syncId,
      {String? label}) async {
    _logInfo('📤 Uploading file for document with sync ID: $syncId');

    try {
      // Validate that the document exists
      final document = await _databaseService.getDocumentBySyncId(syncId);
      if (document == null) {
        throw Exception('Document with sync ID $syncId not found');
      }

      // Upload file to S3 using PersistentFileService for User Pool sub-based paths
      final fileName = path.basename(filePath);
      final s3Key = await _persistentFileService.uploadFile(filePath, syncId);
      _logInfo('✅ File uploaded to S3 using User Pool sub-based path: $s3Key');

      // Get file information
      final file = File(filePath);
      final fileSize = await file.length();
      final contentType = _getContentType(fileName);

      // Generate unique syncId for this FileAttachment (NOT the document's syncId)
      final fileAttachmentSyncId = SyncIdentifierService.generateValidated();

      // Create file attachment record with unique syncId
      final attachment = FileAttachment(
        userId: document.userId, // Get userId from the document
        syncId: fileAttachmentSyncId, // Unique syncId for this FileAttachment
        filePath: filePath,
        fileName: fileName,
        label: label,
        fileSize: fileSize,
        s3Key: s3Key,
        addedAt: amplify_core.TemporalDateTime.now(),
        syncState: 'synced',
        contentType: contentType,
      );

      // Save to database with the generated FileAttachment syncId
      await _databaseService.addFileToDocumentBySyncId(
        syncId, // Document syncId
        filePath,
        label,
        s3Key: s3Key,
        fileAttachmentSyncId: fileAttachmentSyncId, // FileAttachment syncId
      );

      _logInfo('✅ File attachment created for sync ID: $syncId');
      return attachment;
    } catch (e) {
      _logError('❌ Failed to upload file for sync ID $syncId: $e');
      rethrow;
    }
  }

  /// Upload multiple files for a document using sync identifier
  /// Uses User Pool sub-based paths via PersistentFileService for consistent file access
  Future<List<FileAttachment>> uploadFilesForDocument(
      List<String> filePaths, String syncId,
      {Map<String, String>? fileLabels}) async {
    _logInfo('📤 Uploading ${filePaths.length} files for sync ID: $syncId');

    final attachments = <FileAttachment>[];

    try {
      // Validate that the document exists
      final document = await _databaseService.getDocumentBySyncId(syncId);
      if (document == null) {
        throw Exception('Document with sync ID $syncId not found');
      }

      // Upload files using PersistentFileService for User Pool sub-based paths
      for (final filePath in filePaths) {
        try {
          final fileName = path.basename(filePath);
          final s3Key =
              await _persistentFileService.uploadFile(filePath, syncId);
          _logInfo(
              '✅ File uploaded to S3 using User Pool sub-based path: $s3Key');

          final file = File(filePath);
          final fileSize = await file.length();
          final label = fileLabels?[filePath];
          final contentType = _getContentType(fileName);

          // Generate unique syncId for this FileAttachment (NOT the document's syncId)
          final fileAttachmentSyncId =
              SyncIdentifierService.generateValidated();

          final attachment = FileAttachment(
            userId: document.userId, // Get userId from the document
            syncId:
                fileAttachmentSyncId, // Unique syncId for this FileAttachment
            filePath: filePath,
            fileName: fileName,
            label: label,
            fileSize: fileSize,
            s3Key: s3Key,
            addedAt: amplify_core.TemporalDateTime.now(),
            syncState: 'synced',
            contentType: contentType,
          );

          // Save to database with the generated FileAttachment syncId
          await _databaseService.addFileToDocumentBySyncId(
            syncId, // Document syncId
            filePath,
            label,
            s3Key: s3Key,
            fileAttachmentSyncId: fileAttachmentSyncId, // FileAttachment syncId
          );
          attachments.add(attachment);
        } catch (e) {
          _logWarning('⚠️ Failed to upload file $filePath: $e');
          // Continue with other files
        }
      }

      _logInfo('✅ Uploaded ${attachments.length} files for sync ID: $syncId');
      return attachments;
    } catch (e) {
      _logError('❌ Failed to upload files for sync ID $syncId: $e');
      rethrow;
    }
  }

  /// Download a file using sync identifier and User Pool sub-based paths
  /// Uses PersistentFileService for consistent file access across app reinstalls
  Future<String> downloadFile(String s3Key, String syncId) async {
    _logInfo('📥 Downloading file: $s3Key for sync ID: $syncId');

    try {
      // Use PersistentFileService for User Pool sub-based file download
      final localPath =
          await _persistentFileService.downloadFile(s3Key, syncId);
      _logInfo(
          '✅ File downloaded using User Pool sub-based access to: $localPath');
      return localPath;
    } catch (e) {
      _logError('❌ Failed to download file $s3Key: $e');
      rethrow;
    }
  }

  /// Get file attachments for a document by sync identifier
  Future<List<FileAttachment>> getFileAttachmentsForDocument(
      String syncId) async {
    _logInfo('📋 Getting file attachments for sync ID: $syncId');

    try {
      final attachments =
          await _databaseService.getFileAttachmentsByDocumentSyncId(syncId);
      _logInfo(
          '📋 Found ${attachments.length} attachments for sync ID: $syncId');
      return attachments;
    } catch (e) {
      _logError('❌ Failed to get file attachments for sync ID $syncId: $e');
      rethrow;
    }
  }

  /// Delete a file attachment using sync identifier and User Pool sub-based paths
  /// Uses PersistentFileService for consistent file deletion
  Future<void> deleteFileAttachment(String s3Key, String syncId) async {
    _logInfo('🗑️ Deleting file attachment: $s3Key for sync ID: $syncId');

    try {
      // Delete from S3 using PersistentFileService for User Pool sub-based access
      await _persistentFileService.deleteFile(s3Key);
      _logInfo(
          '✅ File deleted from S3 using User Pool sub-based access: $s3Key');

      // Remove from database
      final db = await _databaseService.database;
      await db.delete(
        'file_attachments',
        where: 's3Key = ? AND syncId = ?',
        whereArgs: [s3Key, syncId],
      );

      _logInfo('✅ File attachment deleted: $s3Key');
    } catch (e) {
      _logError('❌ Failed to delete file attachment $s3Key: $e');
      rethrow;
    }
  }

  /// Update file attachment label using sync identifier
  Future<void> updateFileAttachmentLabel(
      String s3Key, String syncId, String? label) async {
    _logInfo('🏷️ Updating file attachment label: $s3Key for sync ID: $syncId');

    try {
      final db = await _databaseService.database;
      final rowsAffected = await db.update(
        'file_attachments',
        {'label': label},
        where: 's3Key = ? AND syncId = ?',
        whereArgs: [s3Key, syncId],
      );

      if (rowsAffected == 0) {
        throw Exception(
            'File attachment not found: $s3Key for sync ID $syncId');
      }

      _logInfo('✅ File attachment label updated: $s3Key');
    } catch (e) {
      _logError('❌ Failed to update file attachment label $s3Key: $e');
      rethrow;
    }
  }

  /// Migrate file attachments to User Pool sub-based paths
  /// Uses PersistentFileService for consistent file migration
  Future<void> migrateFileAttachmentPaths(String syncId) async {
    _logInfo(
        '🔄 Migrating file attachments to User Pool sub-based paths for sync ID: $syncId');

    try {
      // Check if user is authenticated for migration
      if (!await _persistentFileService.isUserAuthenticated()) {
        throw Exception('User not authenticated - cannot perform migration');
      }

      // Get all file attachments for this document
      final attachments = await getFileAttachmentsForDocument(syncId);

      if (attachments.isEmpty) {
        _logInfo('✅ No file attachments to migrate for sync ID: $syncId');
        return;
      }

      // Use PersistentFileService migration capabilities
      await _persistentFileService.migrateUserFiles();

      _logInfo('✅ File attachment migration completed for sync ID: $syncId');
    } catch (e) {
      _logError('❌ Failed to migrate file attachments for sync ID $syncId: $e');
      rethrow;
    }
  }

  /// Get content type based on file extension
  String _getContentType(String fileName) {
    final extension = path.extension(fileName).toLowerCase();

    switch (extension) {
      case '.pdf':
        return 'application/pdf';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.txt':
        return 'text/plain';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  /// Validate that all file attachments for a document use sync identifiers
  Future<bool> validateFileAttachmentsUseSyncId(String syncId) async {
    try {
      final db = await _databaseService.database;

      // Check if any attachments for this sync ID are missing sync ID
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM file_attachments
        WHERE syncId = ? AND (syncId IS NULL OR syncId = '')
      ''', [syncId]);

      final missingCount = result.first['count'] as int;
      return missingCount == 0;
    } catch (e) {
      _logError(
          '❌ Failed to validate file attachments for sync ID $syncId: $e');
      return false;
    }
  }

  /// Get file attachment statistics for a document
  Future<FileAttachmentStats> getFileAttachmentStats(String syncId) async {
    try {
      final attachments = await getFileAttachmentsForDocument(syncId);

      int totalSize = 0;
      int syncedCount = 0;
      final Map<String, int> typeCount = {};

      for (final attachment in attachments) {
        totalSize += attachment.fileSize;

        if (attachment.syncState == 'synced') {
          syncedCount++;
        }

        final extension = path.extension(attachment.fileName).toLowerCase();
        typeCount[extension] = (typeCount[extension] ?? 0) + 1;
      }

      return FileAttachmentStats(
        totalCount: attachments.length,
        totalSize: totalSize,
        syncedCount: syncedCount,
        typeCount: typeCount,
      );
    } catch (e) {
      _logError(
          '❌ Failed to get file attachment stats for sync ID $syncId: $e');
      return FileAttachmentStats(
        totalCount: 0,
        totalSize: 0,
        syncedCount: 0,
        typeCount: {},
      );
    }
  }
}

/// Statistics about file attachments for a document
class FileAttachmentStats {
  final int totalCount;
  final int totalSize;
  final int syncedCount;
  final Map<String, int> typeCount;

  FileAttachmentStats({
    required this.totalCount,
    required this.totalSize,
    required this.syncedCount,
    required this.typeCount,
  });

  int get pendingCount => totalCount - syncedCount;
  double get syncProgress =>
      totalCount > 0 ? (syncedCount / totalCount) * 100 : 100;

  String get formattedSize {
    if (totalSize < 1024) {
      return '${totalSize}B';
    }
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)}KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  String toString() {
    return 'FileAttachmentStats(count: $totalCount, size: $formattedSize, synced: $syncedCount, progress: ${syncProgress.toStringAsFixed(1)}%)';
  }
}
