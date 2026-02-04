import 'dart:io';
import 'dart:math';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'log_service.dart' as log_svc;
import 'authentication_service.dart';

/// Custom exceptions for file operations
class FileUploadException implements Exception {
  final String message;
  FileUploadException(this.message);

  @override
  String toString() => 'FileUploadException: $message';
}

class FileDownloadException implements Exception {
  final String message;
  FileDownloadException(this.message);

  @override
  String toString() => 'FileDownloadException: $message';
}

class FileDeletionException implements Exception {
  final String message;
  FileDeletionException(this.message);

  @override
  String toString() => 'FileDeletionException: $message';
}

/// Service for handling all S3 file operations using Identity Pool ID for paths
class FileService {
  static final FileService _instance = FileService._internal();
  factory FileService() => _instance;
  FileService._internal();

  final _logService = log_svc.LogService();
  final _authService = AuthenticationService();
  static const int _maxRetries = 3;

  /// Generate S3 path using format: private/{identityPoolId}/documents/{syncId}/{fileName}
  String generateS3Path({
    required String identityPoolId,
    required String syncId,
    required String fileName,
  }) {
    // Validate inputs
    if (!_isValidIdentityPoolId(identityPoolId)) {
      throw ArgumentError('Invalid Identity Pool ID format: $identityPoolId');
    }

    if (syncId.isEmpty) {
      throw ArgumentError('syncId cannot be empty');
    }

    if (fileName.isEmpty) {
      throw ArgumentError('fileName cannot be empty');
    }

    // Prevent path traversal attacks
    if (fileName.contains('/') || fileName.contains('\\')) {
      throw ArgumentError('fileName cannot contain path separators: $fileName');
    }

    if (syncId.contains('/') || syncId.contains('\\')) {
      throw ArgumentError('syncId cannot contain path separators: $syncId');
    }

    return 'private/$identityPoolId/documents/$syncId/$fileName';
  }

  /// Validate S3 key ownership by checking if it contains the current user's Identity Pool ID
  bool validateS3KeyOwnership(String s3Key, String identityPoolId) {
    if (s3Key.isEmpty || identityPoolId.isEmpty) {
      return false;
    }

    // S3 key should start with private/{identityPoolId}/
    final expectedPrefix = 'private/$identityPoolId/';
    return s3Key.startsWith(expectedPrefix);
  }

  /// Validate Identity Pool ID format
  /// Expected format: region:uuid (e.g., us-east-1:12345678-1234-1234-1234-123456789012)
  bool _isValidIdentityPoolId(String identityId) {
    final pattern = RegExp(r'^[a-z]{2}-[a-z]+-\d+:[a-f0-9-]+$');
    return pattern.hasMatch(identityId);
  }

  /// Get user-specific file directory
  /// Returns a directory in the format: {appDir}/files/{userId}/
  /// For unauthenticated users, returns: {appDir}/files/guest/
  Future<Directory> _getUserFileDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();

    String userId = 'guest';
    try {
      if (await _authService.isAuthenticated()) {
        userId = await _authService.getUserId();
      }
    } catch (e) {
      _logService.log(
        'Failed to get user ID for file storage, using guest: $e',
        level: log_svc.LogLevel.warning,
      );
    }

    final userFileDir = Directory(path.join(appDir.path, 'files', userId));

    if (!await userFileDir.exists()) {
      await userFileDir.create(recursive: true);
      _logService.log(
        'Created user file directory: ${userFileDir.path}',
        level: log_svc.LogLevel.info,
      );
    }

    return userFileDir;
  }

  /// Upload file to S3 with retry logic
  /// Files are stored in user-specific local directories before upload
  Future<String> uploadFile({
    required String localFilePath,
    required String syncId,
    required String identityPoolId,
  }) async {
    final fileName = path.basename(localFilePath);
    final s3Path = generateS3Path(
      identityPoolId: identityPoolId,
      syncId: syncId,
      fileName: fileName,
    );

    _logService.log(
      'Starting file upload: $fileName to $s3Path',
      level: log_svc.LogLevel.info,
    );

    // Ensure file is in user-specific directory
    final userDir = await _getUserFileDirectory();
    final userFilePath = path.join(userDir.path, fileName);

    // Copy to user directory if not already there
    if (localFilePath != userFilePath) {
      try {
        final sourceFile = File(localFilePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(userFilePath);
          _logService.log(
            'Copied file to user directory: $userFilePath',
            level: log_svc.LogLevel.info,
          );
        }
      } catch (e) {
        _logService.log(
          'Failed to copy file to user directory: $e',
          level: log_svc.LogLevel.warning,
        );
        // Continue with original path if copy fails
      }
    }

    // Use the user-specific path for upload
    final uploadPath =
        await File(userFilePath).exists() ? userFilePath : localFilePath;

    int attempt = 0;
    Exception? lastException;

    while (attempt < _maxRetries) {
      attempt++;

      try {
        final file = File(uploadPath);

        if (!await file.exists()) {
          throw FileUploadException('Local file not found: $uploadPath');
        }

        final result = await Amplify.Storage.uploadFile(
          localFile: AWSFile.fromPath(uploadPath),
          path: StoragePath.fromString(s3Path),
        ).result;

        _logService.log(
          'File upload successful: ${result.uploadedItem.path} (attempt $attempt)',
          level: log_svc.LogLevel.info,
        );

        return result.uploadedItem.path;
      } on StorageException catch (e) {
        lastException = FileUploadException('Storage error: ${e.message}');
        _logService.log(
          'File upload failed (attempt $attempt/$_maxRetries): $fileName - ${e.message}',
          level: log_svc.LogLevel.error,
        );
      } catch (e) {
        lastException = FileUploadException('Upload failed: $e');
        _logService.log(
          'File upload failed (attempt $attempt/$_maxRetries): $fileName - $e',
          level: log_svc.LogLevel.error,
        );
      }

      if (attempt < _maxRetries) {
        // Exponential backoff: 2^attempt seconds
        final delaySeconds = pow(2, attempt).toInt();
        _logService.log(
          'Retrying upload in $delaySeconds seconds...',
          level: log_svc.LogLevel.warning,
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    // All retries failed
    throw lastException ??
        FileUploadException('Upload failed after $_maxRetries attempts');
  }

  /// Download file from S3 with retry logic
  /// Files are downloaded to user-specific local directories
  Future<String> downloadFile({
    required String s3Key,
    required String syncId,
    required String identityPoolId,
  }) async {
    // Validate ownership
    if (!validateS3KeyOwnership(s3Key, identityPoolId)) {
      throw FileDownloadException(
        'S3 key does not belong to current user: $s3Key',
      );
    }

    final fileName = path.basename(s3Key);
    _logService.log(
      'Starting file download: $fileName from $s3Key',
      level: log_svc.LogLevel.info,
    );

    int attempt = 0;
    Exception? lastException;

    while (attempt < _maxRetries) {
      attempt++;

      try {
        // Use user-specific directory for downloads
        final userDir = await _getUserFileDirectory();
        final localPath = path.join(userDir.path, fileName);

        final result = await Amplify.Storage.downloadFile(
          path: StoragePath.fromString(s3Key),
          localFile: AWSFile.fromPath(localPath),
        ).result;

        _logService.log(
          'File download successful: ${result.localFile.path} (attempt $attempt)',
          level: log_svc.LogLevel.info,
        );

        return result.localFile.path!;
      } on StorageException catch (e) {
        lastException = FileDownloadException('Storage error: ${e.message}');
        _logService.log(
          'File download failed (attempt $attempt/$_maxRetries): $fileName - ${e.message}',
          level: log_svc.LogLevel.error,
        );
      } catch (e) {
        lastException = FileDownloadException('Download failed: $e');
        _logService.log(
          'File download failed (attempt $attempt/$_maxRetries): $fileName - $e',
          level: log_svc.LogLevel.error,
        );
      }

      if (attempt < _maxRetries) {
        // Exponential backoff: 2^attempt seconds
        final delaySeconds = pow(2, attempt).toInt();
        _logService.log(
          'Retrying download in $delaySeconds seconds...',
          level: log_svc.LogLevel.warning,
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    // All retries failed
    throw lastException ??
        FileDownloadException('Download failed after $_maxRetries attempts');
  }

  /// Delete a single file from S3 with retry logic
  Future<void> deleteFile(String s3Key) async {
    final fileName = path.basename(s3Key);
    _logService.log(
      'Starting file deletion: $fileName at $s3Key',
      level: log_svc.LogLevel.info,
    );

    int attempt = 0;
    Exception? lastException;

    while (attempt < _maxRetries) {
      attempt++;

      try {
        await Amplify.Storage.remove(
          path: StoragePath.fromString(s3Key),
        ).result;

        _logService.log(
          'File deletion successful: $fileName (attempt $attempt)',
          level: log_svc.LogLevel.info,
        );

        return;
      } on StorageException catch (e) {
        lastException = FileDeletionException('Storage error: ${e.message}');
        _logService.log(
          'File deletion failed (attempt $attempt/$_maxRetries): $fileName - ${e.message}',
          level: log_svc.LogLevel.error,
        );
      } catch (e) {
        lastException = FileDeletionException('Deletion failed: $e');
        _logService.log(
          'File deletion failed (attempt $attempt/$_maxRetries): $fileName - $e',
          level: log_svc.LogLevel.error,
        );
      }

      if (attempt < _maxRetries) {
        // Exponential backoff: 2^attempt seconds
        final delaySeconds = pow(2, attempt).toInt();
        _logService.log(
          'Retrying deletion in $delaySeconds seconds...',
          level: log_svc.LogLevel.warning,
        );
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    // All retries failed
    throw lastException ??
        FileDeletionException('Deletion failed after $_maxRetries attempts');
  }

  /// Delete all files for a document (all files with the syncId prefix)
  Future<void> deleteDocumentFiles({
    required String syncId,
    required String identityPoolId,
    required List<String> s3Keys,
  }) async {
    _logService.log(
      'Starting deletion of ${s3Keys.length} files for document $syncId',
      level: log_svc.LogLevel.info,
    );

    final errors = <String>[];

    for (final s3Key in s3Keys) {
      try {
        // Validate ownership before deletion
        if (!validateS3KeyOwnership(s3Key, identityPoolId)) {
          _logService.log(
            'Skipping deletion of file not owned by user: $s3Key',
            level: log_svc.LogLevel.warning,
          );
          continue;
        }

        await deleteFile(s3Key);
      } catch (e) {
        final fileName = path.basename(s3Key);
        errors.add('$fileName: $e');
        _logService.log(
          'Failed to delete file: $fileName - $e',
          level: log_svc.LogLevel.error,
        );
      }
    }

    if (errors.isNotEmpty) {
      throw FileDeletionException(
        'Failed to delete ${errors.length} file(s): ${errors.join(', ')}',
      );
    }

    _logService.log(
      'Successfully deleted all files for document $syncId',
      level: log_svc.LogLevel.info,
    );
  }

  /// Get local file size
  Future<int?> getFileSize(String localFilePath) async {
    try {
      final file = File(localFilePath);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      _logService.log('Failed to get file size: $localFilePath - $e',
          level: log_svc.LogLevel.error);
      return null;
    }
  }

  /// Check if local file exists
  Future<bool> fileExists(String localFilePath) async {
    try {
      final file = File(localFilePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Delete local file
  Future<void> deleteLocalFile(String localFilePath) async {
    try {
      final file = File(localFilePath);
      if (await file.exists()) {
        await file.delete();
        _logService.log('Deleted local file: $localFilePath',
            level: log_svc.LogLevel.info);
      }
    } catch (e) {
      _logService.log('Failed to delete local file: $localFilePath - $e',
          level: log_svc.LogLevel.error);
    }
  }

  /// Clear all files for current user
  /// Used for cleanup and testing purposes
  Future<void> clearUserFiles() async {
    try {
      final userDir = await _getUserFileDirectory();

      if (await userDir.exists()) {
        await userDir.delete(recursive: true);
        _logService.log(
          'Cleared user files: ${userDir.path}',
          level: log_svc.LogLevel.info,
        );
      }
    } catch (e) {
      _logService.log(
        'Failed to clear user files: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }
}
