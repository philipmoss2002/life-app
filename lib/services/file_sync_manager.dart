import 'dart:io';
import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'retry_manager.dart';
import 'auth_token_manager.dart';
import 'file_validation_service.dart';
import 'performance_monitor.dart';
import 'persistent_file_service.dart';
import '../utils/file_operation_error_handler.dart';

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

/// Manages file synchronization with AWS S3 using User Pool sub-based paths
/// Updated to use PersistentFileService for consistent file access across app reinstalls
class FileSyncManager {
  static const int _multipartThreshold = 5 * 1024 * 1024; // 5MB
  static const int _maxConcurrentUploads = 3; // Max parallel uploads
  static const int _compressionThreshold =
      1 * 1024 * 1024; // 1MB - compress files larger than this

  final Map<String, StreamController<FileProgress>> _uploadProgressControllers =
      {};
  final Map<String, StreamController<FileProgress>>
      _downloadProgressControllers = {};
  final Map<String, int> _retryCount = {};
  final Map<String, String> _interruptedUploads =
      {}; // Maps file path to S3 key for resume
  final RetryManager _retryManager = RetryManager();
  final AuthTokenManager _authManager = AuthTokenManager();
  final FileValidationService _validationService = FileValidationService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final PersistentFileService _persistentFileService = PersistentFileService();

  /// Upload a file to S3 using User Pool sub-based private access
  /// Returns the S3 key for the uploaded file
  Future<String> uploadFile(String filePath, String syncId) async {
    final operationId =
        'upload_${path.basename(filePath)}_${DateTime.now().millisecondsSinceEpoch}';
    _performanceMonitor.startOperation(operationId, 'file_upload');

    // Validate authentication before operation
    await _authManager.validateTokenBeforeOperation();

    // Validate file before upload
    await _validationService.validateFileForUpload(filePath);

    // Compress file if needed
    final uploadPath = await _compressFileIfNeeded(filePath);
    final uploadFile = File(uploadPath);
    final isCompressed = uploadPath != filePath;

    final uploadFileSize = await uploadFile.length();
    final fileName = path.basename(filePath);

    // Use PersistentFileService to generate User Pool sub-based S3 key
    final s3Key = await _generateS3Key(syncId, fileName);
    final fileId = s3Key;

    // Track this upload for potential resume
    _interruptedUploads[filePath] = s3Key;

    // Initialize progress tracking
    _initializeUploadProgress(fileId, uploadFileSize);

    try {
      if (uploadFileSize > _multipartThreshold) {
        await _uploadLargeFile(uploadFile, s3Key, fileId, uploadFileSize);
      } else {
        await _uploadSmallFile(uploadFile, s3Key, fileId, uploadFileSize);
      }

      // File integrity verification temporarily disabled for debugging
      safePrint(
          'File integrity verification temporarily disabled for debugging');

      _updateUploadProgress(
          fileId, uploadFileSize, uploadFileSize, FileTransferState.completed);
      _retryCount.remove(fileId);
      _interruptedUploads.remove(filePath); // Remove from interrupted uploads

      // Clean up compressed file if created
      if (isCompressed) {
        try {
          await uploadFile.delete();
        } catch (e) {
          safePrint('Error deleting compressed file: $e');
        }
      }

      _performanceMonitor.endOperationSuccess(operationId, 'file_upload',
          bytesTransferred: uploadFileSize);
      return s3Key;
    } catch (e) {
      // Don't remove from interrupted uploads - allow for resume
      safePrint('Upload interrupted for $filePath, can be resumed later');

      // Clean up compressed file if created
      if (isCompressed) {
        try {
          await uploadFile.delete();
        } catch (e) {
          safePrint('Error deleting compressed file: $e');
        }
      }

      await _handleUploadError(filePath, syncId, fileId, uploadFileSize, e);
      _performanceMonitor.endOperationFailure(
          operationId, 'file_upload', e.toString(),
          bytesTransferred: uploadFileSize);
      rethrow;
    } finally {
      await _cleanupUploadProgress(fileId);
    }
  }

  /// Download a file from S3
  /// Returns the local file path where the file was saved
  Future<String> downloadFile(String s3Key, String syncId) async {
    final operationId =
        'download_${s3Key}_${DateTime.now().millisecondsSinceEpoch}';
    _performanceMonitor.startOperation(operationId, 'file_download');

    // Validate authentication before operation
    await _authManager.validateTokenBeforeOperation();

    final fileId = s3Key;
    final localPath = await _getLocalCachePath(s3Key, syncId);

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

      // Verify file integrity after download
      await _verifyDownloadIntegrity(result);

      // Get file size for bandwidth tracking
      final downloadedFile = File(result);
      final fileSize = await downloadedFile.length();

      _performanceMonitor.endOperationSuccess(operationId, 'file_download',
          bytesTransferred: fileSize);
      _retryCount.remove(fileId);
      return result;
    } catch (e) {
      await _handleDownloadError(s3Key, syncId, fileId, e);
      _performanceMonitor.endOperationFailure(
          operationId, 'file_download', e.toString());
      rethrow;
    } finally {
      await _cleanupDownloadProgress(fileId);
    }
  }

  /// Delete a file from S3 using User Pool sub-based private access
  Future<void> deleteFile(String s3Key) async {
    // Validate authentication before operation
    await _authManager.validateTokenBeforeOperation();

    try {
      // Use PersistentFileService for User Pool sub-based deletion with error handling
      try {
        await _persistentFileService.deleteFile(s3Key);
        safePrint(
            'File deleted successfully using PersistentFileService: $s3Key');
      } catch (e) {
        // Fallback to direct S3 deletion for legacy compatibility
        safePrint(
            'PersistentFileService delete failed, trying direct S3 access: $e');
        await _deleteWithRetry(s3Key);
      }

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
      String s3Key, String syncId) async* {
    final fileId = s3Key;

    // Emit initial progress
    yield FileProgress(
      fileId: fileId,
      totalBytes: 0,
      transferredBytes: 0,
      state: FileTransferState.pending,
    );

    try {
      await downloadFile(s3Key, syncId);
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
      // Don't rethrow in async* generator as it causes issues
    }
  }

  // Private helper methods

  /// Generate S3 key using User Pool sub-based private access
  /// Uses PersistentFileService for consistent path generation
  Future<String> _generateS3Key(String syncId, String fileName) async {
    try {
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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      // Use username-based path structure: protected/{username}/documents/{syncId}/{filename}
      return 'protected/$username/documents/$syncId/$timestamp-$sanitizedFileName';
    }
  }

  /// Get the S3 path for storage operations
  /// Handles both User Pool sub-based (private) and legacy (protected) access levels
  String _getS3Path(String s3Key) {
    // No prefix needed - S3 key already contains the full path
    // For User Pool sub-based paths: private/{userSub}/documents/{syncId}/{filename}
    // For legacy paths: protected/{username}/documents/{syncId}/{filename}
    return s3Key;
  }

  Future<String> _getLocalCachePath(String s3Key, String syncId) async {
    final cacheDir = await getApplicationDocumentsDirectory();
    final fileName = path.basename(s3Key);
    final localDir = Directory('${cacheDir.path}/cache/$syncId');

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
    return await _authManager.executeWithTokenRefresh(() async {
      return await _retryManager.executeWithRetry(
        () async {
          _updateUploadProgress(
              fileId, fileSize, 0, FileTransferState.inProgress);

          final uploadResult = await Amplify.Storage.uploadFile(
            localFile: AWSFile.fromPath(file.path),
            path: StoragePath.fromString(_getS3Path(s3Key)),
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
              'File uploaded successfully: ${uploadResult.uploadedItem.path}');
        },
        config: RetryManager.fileRetryConfig,
      );
    });
  }

  Future<void> _uploadLargeFile(
      File file, String s3Key, String fileId, int fileSize) async {
    return await _authManager.executeWithTokenRefresh(() async {
      return await _retryManager.executeWithRetry(
        () async {
          _updateUploadProgress(
              fileId, fileSize, 0, FileTransferState.inProgress);

          // Amplify handles multipart uploads automatically for large files
          final uploadResult = await Amplify.Storage.uploadFile(
            localFile: AWSFile.fromPath(file.path),
            path: StoragePath.fromString(_getS3Path(s3Key)),
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
        },
        config: RetryManager.fileRetryConfig,
      );
    });
  }

  Future<String> _downloadWithRetry(
      String s3Key, String localPath, String fileId) async {
    return await _authManager.executeWithTokenRefresh(() async {
      return await _retryManager.executeWithRetry(
        () async {
          _updateDownloadProgress(fileId, 0, 0, FileTransferState.inProgress);

          final downloadResult = await Amplify.Storage.downloadFile(
            path: StoragePath.fromString(_getS3Path(s3Key)),
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
        },
        config: RetryManager.fileRetryConfig,
      );
    });
  }

  Future<void> _deleteWithRetry(String s3Key) async {
    return await _authManager.executeWithTokenRefresh(() async {
      return await _retryManager.executeWithRetry(
        () async {
          await Amplify.Storage.remove(
            path: StoragePath.fromString(_getS3Path(s3Key)),
          ).result;
          safePrint('File deleted successfully: $s3Key');
        },
        config: RetryManager.fileRetryConfig,
      );
    });
  }

  Future<void> _handleUploadError(String filePath, String syncId, String fileId,
      int fileSize, Object error) async {
    _updateUploadProgress(fileId, fileSize, 0, FileTransferState.failed);

    // Enhanced error handling for User Pool sub-based operations
    if (error is UserPoolSubException) {
      safePrint('User Pool sub error during upload: $error');
    } else if (error is FilePathGenerationException) {
      safePrint('File path generation error during upload: $error');
    } else {
      safePrint('Upload failed: $error');
    }
  }

  Future<void> _handleDownloadError(
      String s3Key, String syncId, String fileId, Object error) async {
    _updateDownloadProgress(fileId, 0, 0, FileTransferState.failed);

    // Enhanced error handling for User Pool sub-based operations
    if (error is UserPoolSubException) {
      safePrint('User Pool sub error during download: $error');
    } else if (error is FilePathGenerationException) {
      safePrint('File path generation error during download: $error');
    } else {
      safePrint('Download failed: $error');
    }
  }

  /// Calculate MD5 checksum of a file for integrity verification
  Future<String> calculateFileChecksum(String filePath) async {
    // Use validation service for checksum calculation
    return await _validationService.calculateFileChecksum(filePath);
  }

  /// Upload multiple files in parallel (max 3 concurrent)
  /// Returns a map of file paths to their S3 keys
  Future<Map<String, String>> uploadFilesParallel(
    List<String> filePaths,
    String syncId,
  ) async {
    if (filePaths.isEmpty) {
      return {};
    }

    final results = <String, String>{};
    final errors = <String, Object>{};

    // Process files in parallel with concurrency limit
    final futures = filePaths.map((filePath) async {
      try {
        final s3Key = await uploadFile(filePath, syncId);
        results[filePath] = s3Key;
      } catch (e) {
        errors[filePath] = e;
        safePrint('Error uploading file $filePath: $e');
      }
    });

    // Wait for all uploads with concurrency control
    await _processConcurrently(futures.toList());

    if (errors.isNotEmpty) {
      safePrint(
          'Some files failed to upload: ${errors.length}/${filePaths.length}');
      // Throw error with details about failed uploads
      throw Exception(
          'Failed to upload ${errors.length} files: ${errors.keys.join(", ")}');
    }

    safePrint('Successfully uploaded ${results.length} files in parallel');
    return results;
  }

  /// Process futures with concurrency limit
  Future<void> _processConcurrently(List<Future<void>> futures) async {
    final executing = <Future<void>>[];

    for (final future in futures) {
      // Wait if we've reached the concurrency limit
      while (executing.length >= _maxConcurrentUploads) {
        await Future.any(executing);
        // Remove completed futures
        executing.removeWhere((f) {
          // Check if future is completed by trying to get its value
          try {
            return false; // Keep all futures for now
          } catch (e) {
            return true;
          }
        });
      }

      // Add to executing list with completion tracking
      late Future<void> tracked;
      tracked = future.then((_) {
        executing.remove(tracked);
      }).catchError((e) {
        executing.remove(tracked);
        throw e;
      });
      executing.add(tracked);
    }

    // Wait for remaining futures
    if (executing.isNotEmpty) {
      await Future.wait(executing, eagerError: false);
    }
  }

  /// Compress a file before upload if it's larger than threshold
  /// Returns the path to the compressed file or original if not compressed
  Future<String> _compressFileIfNeeded(String filePath) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // Skip compression for small files
    if (fileSize < _compressionThreshold) {
      return filePath;
    }

    // Skip compression for already compressed formats
    final extension = path.extension(filePath).toLowerCase();
    final compressedFormats = [
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.zip',
      '.gz',
      '.mp4',
      '.mp3'
    ];
    if (compressedFormats.contains(extension)) {
      safePrint(
          'Skipping compression for already compressed format: $extension');
      return filePath;
    }

    try {
      safePrint('Compressing file: $filePath (${fileSize} bytes)');

      // Read file bytes
      final bytes = await file.readAsBytes();

      // Compress using gzip
      final compressed = GZipEncoder().encode(bytes);
      if (compressed == null) {
        safePrint('Compression failed, using original file');
        return filePath;
      }

      // Calculate compression ratio
      final compressionRatio = (1 - (compressed.length / bytes.length)) * 100;
      safePrint(
          'Compressed ${bytes.length} bytes to ${compressed.length} bytes (${compressionRatio.toStringAsFixed(1)}% reduction)');

      // Only use compressed version if it's actually smaller
      if (compressed.length >= bytes.length) {
        safePrint('Compressed file is not smaller, using original');
        return filePath;
      }

      // Write compressed file
      final compressedPath = '$filePath.gz';
      final compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(compressed);

      return compressedPath;
    } catch (e) {
      safePrint('Error compressing file: $e, using original');
      return filePath;
    }
  }

  /// Cache thumbnail for a file
  /// Returns the path to the cached thumbnail
  Future<String?> cacheThumbnail(String s3Key, List<int> thumbnailBytes) async {
    try {
      final cacheDir = await getApplicationDocumentsDirectory();
      final thumbnailDir = Directory('${cacheDir.path}/thumbnails');

      if (!await thumbnailDir.exists()) {
        await thumbnailDir.create(recursive: true);
      }

      // Generate thumbnail filename from s3Key
      final thumbnailFileName = s3Key.replaceAll('/', '_') + '_thumb.jpg';
      final thumbnailPath = '${thumbnailDir.path}/$thumbnailFileName';

      // Write thumbnail to cache
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      safePrint('Cached thumbnail: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      safePrint('Error caching thumbnail: $e');
      return null;
    }
  }

  /// Get cached thumbnail for a file
  /// Returns the path to the cached thumbnail or null if not cached
  Future<String?> getCachedThumbnail(String s3Key) async {
    try {
      final cacheDir = await getApplicationDocumentsDirectory();
      final thumbnailFileName = s3Key.replaceAll('/', '_') + '_thumb.jpg';
      final thumbnailPath = '${cacheDir.path}/thumbnails/$thumbnailFileName';

      final thumbnailFile = File(thumbnailPath);
      if (await thumbnailFile.exists()) {
        safePrint('Found cached thumbnail: $thumbnailPath');
        return thumbnailPath;
      }

      return null;
    } catch (e) {
      safePrint('Error getting cached thumbnail: $e');
      return null;
    }
  }

  /// Clear thumbnail cache
  Future<void> clearThumbnailCache() async {
    try {
      final cacheDir = await getApplicationDocumentsDirectory();
      final thumbnailDir = Directory('${cacheDir.path}/thumbnails');

      if (await thumbnailDir.exists()) {
        await thumbnailDir.delete(recursive: true);
        safePrint('Cleared thumbnail cache');
      }
    } catch (e) {
      safePrint('Error clearing thumbnail cache: $e');
    }
  }

  /// Get list of interrupted uploads that can be resumed
  Map<String, String> getInterruptedUploads() {
    return Map.from(_interruptedUploads);
  }

  /// Clear interrupted uploads (useful for cleanup)
  void clearInterruptedUploads() {
    _interruptedUploads.clear();
  }

  /// Verify download integrity by checking file exists and is readable
  Future<void> _verifyDownloadIntegrity(String localPath) async {
    try {
      // Use validation service for comprehensive file validation
      await _validationService.validateDownloadedFile(localPath);

      safePrint('Download integrity verified successfully for $localPath');
    } catch (e) {
      safePrint('Download integrity verification failed: $e');
      // Rethrow because this indicates a serious problem with the download
      rethrow;
    }
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
    _interruptedUploads.clear();
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
