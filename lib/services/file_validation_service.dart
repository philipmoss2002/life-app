import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Exception thrown when file validation fails
class FileValidationException implements Exception {
  final String message;
  final List<String> validationErrors;

  FileValidationException({
    required this.message,
    required this.validationErrors,
  });

  @override
  String toString() =>
      'FileValidationException: $message\nErrors: ${validationErrors.join(', ')}';
}

/// Service for validating file data during upload/download operations
/// Ensures file integrity and prevents corrupted data from being processed
class FileValidationService {
  static final FileValidationService _instance =
      FileValidationService._internal();
  factory FileValidationService() => _instance;
  FileValidationService._internal();

  // File size limits
  static const int maxFileSize = 100 * 1024 * 1024; // 100MB
  static const int minFileSize = 1; // 1 byte minimum

  // Allowed file extensions
  static const Set<String> allowedExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.txt',
    '.rtf',
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.bmp',
    '.tiff',
    '.xls',
    '.xlsx',
    '.csv',
    '.ppt',
    '.pptx',
    '.zip',
    '.rar',
    '.7z',
    '.mp3',
    '.wav',
    '.mp4',
    '.avi',
    '.mov',
  };

  /// Validate a file before upload
  /// Throws FileValidationException if validation fails
  Future<void> validateFileForUpload(String filePath) async {
    final errors = <String>[];

    // Check if file exists
    final file = File(filePath);
    if (!await file.exists()) {
      errors.add('File does not exist: $filePath');
      throw FileValidationException(
        message: 'File validation failed for upload',
        validationErrors: errors,
      );
    }

    // Validate file size
    errors.addAll(await _validateFileSize(file));

    // Validate file extension
    errors.addAll(_validateFileExtension(filePath));

    // Validate file is readable
    errors.addAll(await _validateFileReadability(file));

    if (errors.isNotEmpty) {
      throw FileValidationException(
        message: 'File validation failed for upload',
        validationErrors: errors,
      );
    }
  }

  /// Validate a downloaded file
  /// Throws FileValidationException if validation fails
  Future<void> validateDownloadedFile(String filePath,
      {String? expectedChecksum}) async {
    final errors = <String>[];

    // Check if file exists
    final file = File(filePath);
    if (!await file.exists()) {
      errors.add('Downloaded file does not exist: $filePath');
      throw FileValidationException(
        message: 'Downloaded file validation failed',
        validationErrors: errors,
      );
    }

    // Validate file size
    errors.addAll(await _validateFileSize(file));

    // Validate file extension
    errors.addAll(_validateFileExtension(filePath));

    // Validate file is readable
    errors.addAll(await _validateFileReadability(file));

    // Validate checksum if provided
    if (expectedChecksum != null) {
      errors.addAll(await _validateFileChecksum(file, expectedChecksum));
    }

    if (errors.isNotEmpty) {
      throw FileValidationException(
        message: 'Downloaded file validation failed',
        validationErrors: errors,
      );
    }
  }

  /// Calculate MD5 checksum for a file
  Future<String> calculateFileChecksum(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileValidationException(
        message: 'Cannot calculate checksum for non-existent file',
        validationErrors: ['File does not exist: $filePath'],
      );
    }

    final bytes = await file.readAsBytes();
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Validate file size is within acceptable limits
  Future<List<String>> _validateFileSize(File file) async {
    final errors = <String>[];

    try {
      final fileSize = await file.length();

      if (fileSize < minFileSize) {
        errors.add('File is too small (minimum $minFileSize bytes)');
      }

      if (fileSize > maxFileSize) {
        errors.add(
            'File is too large (maximum ${maxFileSize ~/ (1024 * 1024)}MB)');
      }
    } catch (e) {
      errors.add('Unable to determine file size: $e');
    }

    return errors;
  }

  /// Validate file extension is allowed
  List<String> _validateFileExtension(String filePath) {
    final errors = <String>[];

    final extension = filePath.toLowerCase().split('.').last;
    final fullExtension = '.$extension';

    if (!allowedExtensions.contains(fullExtension)) {
      errors.add(
          'File type not allowed: $fullExtension. Allowed types: ${allowedExtensions.join(', ')}');
    }

    return errors;
  }

  /// Validate file is readable
  Future<List<String>> _validateFileReadability(File file) async {
    final errors = <String>[];

    try {
      // Try to read the first few bytes to ensure file is readable
      final stream = file.openRead(0, 1024);
      await stream.first;
    } catch (e) {
      errors.add('File is not readable: $e');
    }

    return errors;
  }

  /// Validate file checksum matches expected value
  Future<List<String>> _validateFileChecksum(
      File file, String expectedChecksum) async {
    final errors = <String>[];

    try {
      final actualChecksum = await calculateFileChecksum(file.path);
      if (actualChecksum != expectedChecksum) {
        errors.add(
            'File checksum mismatch. Expected: $expectedChecksum, Actual: $actualChecksum');
      }
    } catch (e) {
      errors.add('Unable to validate file checksum: $e');
    }

    return errors;
  }

  /// Sanitize file name to prevent path traversal attacks
  String sanitizeFileName(String fileName) {
    // Remove path separators and dangerous characters
    String sanitized = fileName
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .replaceAll('..', '_')
        .replaceAll('\x00', '');

    // Ensure filename is not empty and not too long
    if (sanitized.isEmpty) {
      sanitized = 'file';
    }

    if (sanitized.length > 255) {
      final extension = sanitized.split('.').last;
      final nameWithoutExt = sanitized.substring(0, sanitized.lastIndexOf('.'));
      sanitized =
          '${nameWithoutExt.substring(0, 250 - extension.length)}.$extension';
    }

    return sanitized;
  }

  /// Validate file metadata structure
  void validateFileMetadata(Map<String, dynamic> metadata) {
    final errors = <String>[];

    // Check required fields
    final requiredFields = ['fileName', 'fileSize', 's3Key'];
    for (final field in requiredFields) {
      if (!metadata.containsKey(field) || metadata[field] == null) {
        errors.add('Missing required metadata field: $field');
      }
    }

    // Validate data types
    if (metadata.containsKey('fileSize') && metadata['fileSize'] is! int) {
      errors.add('File size must be an integer');
    }

    if (metadata.containsKey('fileName') && metadata['fileName'] is! String) {
      errors.add('File name must be a string');
    }

    if (metadata.containsKey('s3Key') && metadata['s3Key'] is! String) {
      errors.add('S3 key must be a string');
    }

    // Validate file size is reasonable
    if (metadata.containsKey('fileSize')) {
      final fileSize = metadata['fileSize'] as int;
      if (fileSize < minFileSize || fileSize > maxFileSize) {
        errors.add('File size out of acceptable range: $fileSize bytes');
      }
    }

    if (errors.isNotEmpty) {
      throw FileValidationException(
        message: 'File metadata validation failed',
        validationErrors: errors,
      );
    }
  }

  /// Check if file type is safe for processing
  bool isFileTypeSafe(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    final fullExtension = '.$extension';
    return allowedExtensions.contains(fullExtension);
  }

  /// Get file type category
  String getFileTypeCategory(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;

    switch (extension) {
      case 'pdf':
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return 'document';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'tiff':
        return 'image';
      case 'xls':
      case 'xlsx':
      case 'csv':
        return 'spreadsheet';
      case 'ppt':
      case 'pptx':
        return 'presentation';
      case 'zip':
      case 'rar':
      case '7z':
        return 'archive';
      case 'mp3':
      case 'wav':
        return 'audio';
      case 'mp4':
      case 'avi':
      case 'mov':
        return 'video';
      default:
        return 'other';
    }
  }
}
