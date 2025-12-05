import 'dart:io';
import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Progress information for file uploads/downloads
class FileProgress {
  final String fileId;
  final int totalBytes;
  final int transferredBytes;
  final double percentage;
  final FileTransferState state;

  FileProgress({
    required this.fileId,
    required this.totalBytes,
    required this.transferredBytes,
    required this.state,
  }) : percentage = totalBytes > 0 ? (transferredBytes / totalBytes) * 100 : 0;

  bool get isComplete => state == FileTransferState.completed;
  bool get isFailed => state == FileTransferState.failed;
  bool get isInProgress => state == FileTransferState.inProgress;
}

enum FileTransferState {
  pending,
  inProgress,
  completed,
  failed,
}

/// Manages file synchronization with AWS S3
class FileSyncManager {
  static const int _multipartThreshold = 5 * 1024 * 1024; // 5MB
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  final Map<String, StreamController<FileProgress>> _uploadProgressControllers =
      {};
  final Map<String, StreamController<FileProgress>>
      _downloadProgressControllers = {};
  final Map<String, int> _retryCount = {};

  /// Upload a file to S3
  /// Returns the S3 key for the uploaded file
  Future<String> uploadFile(String filePath, String documentId) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final fileSize = await file.length();
    final fileName = path.basename(filePath);
    final s3Key = _generateS3Key(documentId, fileName);
    final fileId = s3Key;

    // Initialize progress tracking
    _initializeUploadProgress(fileId, fileSize);

    try {
      if (fileSize > _multipartThreshold) {
        await _uploadLargeFile(file, s3Key, fileId, fileSize);
      } else {
        await _uploadSmallFile(file, s3Key, fileId, fileSize);
      }

      _updateUploadProgress(
          fileId, fileSize, fileSize, FileTransferState.completed);
      _retryCount.remove(fileId);
      return s3Key;
    } catch (e) {
      await _handleUploadError(filePath, documentId, fileId, fileSize, e);
      rethrow;
    } finally {
      await _cleanupUploadProgress(fileId);
    }
  }

  /// Download a file from S3
  /// Returns the local file path where the file was saved
  Future<String> downloadFile(String s3Key, String documentId) async {
    final fileId = s3Key;
    final localPath = await _getLocalCachePath(s3Key, documentId);

    // Check if file already exists in cache
    final cachedFile = File(localPath);
    if (await cachedFile.exists()) {
      safePrint('File already cached: $localPath');
      return localPath;
    }

    // Initialize progress tracking
    _initializeDownloadProgress(fileId, 0);

    try {
      final result = await _downloadWithRetry(s3Key, localPath, fileId);
      _retryCount.remove(fileId);
      return result;
    } catch (e) {
      await _handleDownloadError(s3Key, documentId, fileId, e);
      rethrow;
    } finally {
      await _cleanupDownloadProgress(fileId);
    }
  }

  /// Delete a file from S3
  Future<void> deleteFile(String s3Key) async {
    try {
      await _deleteWithRetry(s3Key);
      _retryCount.remove(s3Key);
    } catch (e) {
      safePrint('Error deleting file from S3: $e');
      rethrow;
    }
  }

  /// Get upload progress for a specific file
  FileProgress? getUploadProgress(String fileId) {
    // This would typically be stored in memory or a database
    // For now, return null if not actively uploading
    return null;
  }

  /// Stream download progress for a file
  Stream<FileProgress> downloadFileWithProgress(
      String s3Key, String documentId) async* {
    final fileId = s3Key;
    final controller = StreamController<FileProgress>();
    _downloadProgressControllers[fileId] = controller;

    try {
      await downloadFile(s3Key, documentId);
      yield FileProgress(
        fileId: fileId,
        totalBytes: 0,
        transferredBytes: 0,
        state: FileTransferState.completed,
      );
    } catch (e) {
      yield FileProgress(
        fileId: fileId,
        totalBytes: 0,
        transferredBytes: 0,
        state: FileTransferState.failed,
      );
      rethrow;
    }
  }

  // Private helper methods

  String _generateS3Key(String documentId, String fileName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final sanitizedFileName =
        fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'documents/$documentId/$timestamp-$sanitizedFileName';
  }

  Future<String> _getLocalCachePath(String s3Key, String documentId) async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(s3Key);
    final localDir = Directory('${cacheDir.path}/cache/$documentId');

    if (!await localDir.exists()) {
      await localDir.create(recursive: true);
    }

    return '${localDir.path}/$fileName';
  }

  void _initializeUploadProgress(String fileId, int totalBytes) {
    final controller = StreamController<FileProgress>.broadcast();
    _uploadProgressControllers[fileId] = controller;
    _updateUploadProgress(fileId, totalBytes, 0, FileTransferState.pending);
  }

  void _updateUploadProgress(String fileId, int totalBytes,
      int transferredBytes, FileTransferState state) {
    final controller = _uploadProgressControllers[fileId];
    if (controller != null && !controller.isClosed) {
      controller.add(FileProgress(
        fileId: fileId,
        totalBytes: totalBytes,
        transferredBytes: transferredBytes,
        state: state,
      ));
    }
  }

  Future<void> _cleanupUploadProgress(String fileId) async {
    final controller = _uploadProgressControllers[fileId];
    if (controller != null) {
      await controller.close();
      _uploadProgressControllers.remove(fileId);
    }
  }

  void _initializeDownloadProgress(String fileId, int totalBytes) {
    final controller = StreamController<FileProgress>.broadcast();
    _downloadProgressControllers[fileId] = controller;
    _updateDownloadProgress(fileId, totalBytes, 0, FileTransferState.pending);
  }

  void _updateDownloadProgress(String fileId, int totalBytes,
      int transferredBytes, FileTransferState state) {
    final controller = _downloadProgressControllers[fileId];
    if (controller != null && !controller.isClosed) {
      controller.add(FileProgress(
        fileId: fileId,
        totalBytes: totalBytes,
        transferredBytes: transferredBytes,
        state: state,
      ));
    }
  }

  Future<void> _cleanupDownloadProgress(String fileId) async {
    final controller = _downloadProgressControllers[fileId];
    if (controller != null) {
      await controller.close();
      _downloadProgressControllers.remove(fileId);
    }
  }

  Future<void> _uploadSmallFile(
      File file, String s3Key, String fileId, int fileSize) async {
    _updateUploadProgress(fileId, fileSize, 0, FileTransferState.inProgress);

    final uploadResult = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      path: StoragePath.fromString(s3Key),
      onProgress: (progress) {
        _updateUploadProgress(
          fileId,
          fileSize,
          progress.transferredBytes,
          FileTransferState.inProgress,
        );
      },
    ).result;

    safePrint('File uploaded successfully: ${uploadResult.uploadedItem.path}');
  }

  Future<void> _uploadLargeFile(
      File file, String s3Key, String fileId, int fileSize) async {
    _updateUploadProgress(fileId, fileSize, 0, FileTransferState.inProgress);

    // Amplify handles multipart uploads automatically for large files
    final uploadResult = await Amplify.Storage.uploadFile(
      localFile: AWSFile.fromPath(file.path),
      path: StoragePath.fromString(s3Key),
      onProgress: (progress) {
        _updateUploadProgress(
          fileId,
          fileSize,
          progress.transferredBytes,
          FileTransferState.inProgress,
        );
      },
    ).result;

    safePrint(
        'Large file uploaded successfully: ${uploadResult.uploadedItem.path}');
  }

  Future<String> _downloadWithRetry(
      String s3Key, String localPath, String fileId) async {
    int retries = 0;

    while (retries <= _maxRetries) {
      try {
        _updateDownloadProgress(fileId, 0, 0, FileTransferState.inProgress);

        final downloadResult = await Amplify.Storage.downloadFile(
          path: StoragePath.fromString(s3Key),
          localFile: AWSFile.fromPath(localPath),
          onProgress: (progress) {
            _updateDownloadProgress(
              fileId,
              progress.totalBytes,
              progress.transferredBytes,
              FileTransferState.inProgress,
            );
          },
        ).result;

        _updateDownloadProgress(fileId, 0, 0, FileTransferState.completed);
        safePrint(
            'File downloaded successfully: ${downloadResult.downloadedItem.path}');
        return localPath;
      } catch (e) {
        retries++;
        if (retries > _maxRetries) {
          _updateDownloadProgress(fileId, 0, 0, FileTransferState.failed);
          rethrow;
        }
        safePrint(
            'Download attempt $retries failed, retrying in ${_retryDelay.inSeconds}s: $e');
        await Future.delayed(_retryDelay * retries); // Exponential backoff
      }
    }

    throw Exception('Download failed after $_maxRetries retries');
  }

  Future<void> _deleteWithRetry(String s3Key) async {
    int retries = 0;

    while (retries <= _maxRetries) {
      try {
        await Amplify.Storage.remove(path: StoragePath.fromString(s3Key))
            .result;
        safePrint('File deleted successfully: $s3Key');
        return;
      } catch (e) {
        retries++;
        if (retries > _maxRetries) {
          rethrow;
        }
        safePrint(
            'Delete attempt $retries failed, retrying in ${_retryDelay.inSeconds}s: $e');
        await Future.delayed(_retryDelay * retries); // Exponential backoff
      }
    }
  }

  Future<void> _handleUploadError(String filePath, String documentId,
      String fileId, int fileSize, Object error) async {
    _updateUploadProgress(fileId, fileSize, 0, FileTransferState.failed);
    safePrint('Upload failed: $error');
  }

  Future<void> _handleDownloadError(
      String s3Key, String documentId, String fileId, Object error) async {
    _updateDownloadProgress(fileId, 0, 0, FileTransferState.failed);
    safePrint('Download failed: $error');
  }

  /// Calculate MD5 checksum of a file for integrity verification
  Future<String> calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Dispose of all resources
  Future<void> dispose() async {
    for (var controller in _uploadProgressControllers.values) {
      await controller.close();
    }
    for (var controller in _downloadProgressControllers.values) {
      await controller.close();
    }
    _uploadProgressControllers.clear();
    _downloadProgressControllers.clear();
    _retryCount.clear();
  }
}
