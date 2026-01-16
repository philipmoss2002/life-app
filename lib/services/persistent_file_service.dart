import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'log_service.dart' as app_log;
import '../models/file_path.dart';
import '../models/file_migration_mapping.dart';
import '../utils/user_pool_sub_validator.dart';
import '../utils/file_operation_error_handler.dart';
import '../utils/data_integrity_validator.dart';
import '../utils/security_validator.dart';

/// Service that manages file operations using persistent User Pool sub identifiers
/// Follows AWS best practices by using S3 private access level with User Pool authentication
/// Ensures consistent file access across app reinstalls and device changes
class PersistentFileService {
  static final PersistentFileService _instance =
      PersistentFileService._internal();
  factory PersistentFileService() => _instance;
  PersistentFileService._internal();

  final app_log.LogService _logService = app_log.LogService();
  final DataIntegrityValidator _dataValidator = DataIntegrityValidator();
  final SecurityValidator _securityValidator = SecurityValidator();

  // Cache for User Pool sub to avoid repeated API calls
  String? _cachedUserPoolSub;
  DateTime? _cacheTimestamp;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);

  /// Core file operations

  /// Upload a file to S3 using User Pool sub-based private access
  /// Returns the S3 key for the uploaded file
  ///
  /// [filePath] - Local path to the file to upload
  /// [syncId] - Sync identifier for organizing files
  ///
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  /// Throws [FilePathGenerationException] if S3 path generation fails
  Future<String> uploadFile(String filePath, String syncId) async {
    return await FileOperationErrorHandler.executeWithRetry(
      () => _uploadFileInternal(filePath, syncId),
      'uploadFile',
      maxRetries: 5, // More retries for uploads
      maxDelay: const Duration(minutes: 2),
      useCircuitBreaker: true,
      queueOnFailure: true, // Queue uploads on network failure
    );
  }

  Future<String> _uploadFileInternal(String filePath, String syncId) async {
    _logInfo(
        '🚀 PersistentFileService: Starting upload for $filePath with syncId: $syncId');

    try {
      // Validate inputs
      if (filePath.isEmpty) {
        throw FilePathGenerationException('File path cannot be empty');
      }
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      // Security validation: Validate user authentication
      if (!await _securityValidator.validateUserAuthentication()) {
        throw UserPoolSubException(
            'Security validation failed: User authentication required');
      }

      // Security validation: Validate secure connection
      if (!await _securityValidator.validateSecureConnection()) {
        throw FileOperationErrorHandler.handleError(Exception(
            'Security validation failed: Secure connection required'));
      }

      // Security validation: Validate file for upload
      if (!await _securityValidator.validateFileForUpload(filePath)) {
        throw FileOperationErrorHandler.handleError(
            Exception('Security validation failed: File not safe for upload'));
      }

      // Validate user authentication before upload (legacy check)
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to upload files');
      }

      // Extract file name from path
      final fileName = filePath.split('/').last;
      if (fileName.isEmpty) {
        throw FilePathGenerationException(
            'Could not extract file name from path: $filePath');
      }

      // Generate S3 path using User Pool sub
      final s3Key = await generateS3Path(syncId, fileName);

      // Security validation: Validate generated S3 path
      if (!await _securityValidator.validateS3Path(s3Key)) {
        throw FilePathGenerationException(
            'Security validation failed: Generated S3 path is not secure');
      }

      // Upload file to S3 using Amplify Storage with private access level
      final uploadResult = await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(filePath),
        path: StoragePath.fromString(s3Key),
      ).result;

      _logInfo(
          '✅ File uploaded successfully: ${uploadResult.uploadedItem.path}');
      return s3Key; // Return the generated S3 key, not the upload result path
    } catch (e) {
      _logError('❌ PersistentFileService upload failed: $e');
      throw FileOperationErrorHandler.handleError(
          e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Download a file from S3 using User Pool sub-based private access
  /// Returns the local path where the file was downloaded
  ///
  /// [s3Key] - S3 key of the file to download
  /// [syncId] - Sync identifier for organizing files
  ///
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<String> downloadFile(String s3Key, String syncId) async {
    return await FileOperationErrorHandler.executeWithRetry(
      () => _downloadFileInternal(s3Key, syncId),
      'downloadFile',
      maxRetries: 3,
      useCircuitBreaker: true,
      queueOnFailure:
          false, // Downloads are typically user-initiated, don't queue
    );
  }

  Future<String> _downloadFileInternal(String s3Key, String syncId) async {
    _logInfo(
        '📥 PersistentFileService: Starting download for $s3Key with syncId: $syncId');

    try {
      // Validate inputs
      if (s3Key.isEmpty) {
        throw FilePathGenerationException('S3 key cannot be empty');
      }
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      // Security validation: Validate user authentication
      if (!await _securityValidator.validateUserAuthentication()) {
        throw UserPoolSubException(
            'Security validation failed: User authentication required');
      }

      // Security validation: Validate secure connection
      if (!await _securityValidator.validateSecureConnection()) {
        throw FileOperationErrorHandler.handleError(Exception(
            'Security validation failed: Secure connection required'));
      }

      // Security validation: Validate S3 path
      if (!await _securityValidator.validateS3Path(s3Key)) {
        throw FilePathGenerationException(
            'Security validation failed: S3 path is not secure or valid');
      }

      // Security validation: Validate file ownership
      if (!await _securityValidator.validateFileOwnership(s3Key)) {
        throw UserPoolSubException(
            'Security validation failed: Access denied - file does not belong to current user');
      }

      // Validate user authentication before download (legacy check)
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to download files');
      }

      // Validate that the S3 key belongs to the current user (legacy check)
      if (!await validateS3KeyOwnership(s3Key)) {
        throw UserPoolSubException(
            'Access denied: S3 key does not belong to current user');
      }

      // Parse S3 key to get file name
      final filePath = parseS3Key(s3Key);
      final fileName = filePath.fileName;

      // Create local file path for download
      final localPath = '/tmp/downloads/$syncId/$fileName';

      // Download file from S3 using Amplify Storage with private access level
      final downloadResult = await Amplify.Storage.downloadFile(
        path: StoragePath.fromString(s3Key),
        localFile: AWSFile.fromPath(localPath),
      ).result;

      _logInfo(
          '✅ File downloaded successfully to: ${downloadResult.localFile.path}');
      return downloadResult.localFile.path ?? localPath;
    } catch (e) {
      _logError('❌ PersistentFileService download failed: $e');
      throw FileOperationErrorHandler.handleError(
          e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Delete a file from S3 using User Pool sub-based private access
  ///
  /// [s3Key] - S3 key of the file to delete
  ///
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<void> deleteFile(String s3Key) async {
    return await FileOperationErrorHandler.executeWithRetry(
      () => _deleteFileInternal(s3Key),
      'deleteFile',
      maxRetries: 3,
      useCircuitBreaker: true,
      queueOnFailure:
          true, // Queue deletions on network failure for eventual consistency
    );
  }

  Future<void> _deleteFileInternal(String s3Key) async {
    _logInfo('🗑️ PersistentFileService: Deleting file $s3Key');

    try {
      // Validate inputs
      if (s3Key.isEmpty) {
        throw FilePathGenerationException('S3 key cannot be empty');
      }

      // Security validation: Validate user authentication
      if (!await _securityValidator.validateUserAuthentication()) {
        throw UserPoolSubException(
            'Security validation failed: User authentication required');
      }

      // Security validation: Validate secure connection
      if (!await _securityValidator.validateSecureConnection()) {
        throw FileOperationErrorHandler.handleError(Exception(
            'Security validation failed: Secure connection required'));
      }

      // Security validation: Validate S3 path
      if (!await _securityValidator.validateS3Path(s3Key)) {
        throw FilePathGenerationException(
            'Security validation failed: S3 path is not secure or valid');
      }

      // Security validation: Validate file ownership
      if (!await _securityValidator.validateFileOwnership(s3Key)) {
        throw UserPoolSubException(
            'Security validation failed: Access denied - file does not belong to current user');
      }

      // Validate user authentication before deletion (legacy check)
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to delete files');
      }

      // Validate that the S3 key belongs to the current user (legacy check)
      if (!await validateS3KeyOwnership(s3Key)) {
        throw UserPoolSubException(
            'Access denied: S3 key does not belong to current user');
      }

      // Delete file from S3 using Amplify Storage with private access level
      await Amplify.Storage.remove(
        path: StoragePath.fromString(s3Key),
      ).result;

      _logInfo('✅ File deleted successfully: $s3Key');
    } catch (e) {
      _logError('❌ PersistentFileService delete failed: $e');
      throw FileOperationErrorHandler.handleError(
          e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Path management

  /// Generate S3 path using User Pool sub and private access level
  /// Format: private/{userSub}/documents/{syncId}/{fileName}
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file
  ///
  /// Returns the complete S3 path for the file
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  /// Throws [FilePathGenerationException] if path generation fails
  Future<String> generateS3Path(String syncId, String fileName) async {
    _logInfo(
        '📍 PersistentFileService: Generating S3 path for syncId: $syncId, fileName: $fileName');

    try {
      // Validate inputs before processing
      _validatePathInputs(syncId, fileName);

      // Use the FilePath model for consistent path generation
      final filePath = await generateFilePath(syncId, fileName);

      // Validate the generated path
      if (!_validateGeneratedPath(filePath.s3Key)) {
        throw FilePathGenerationException(
            'Generated path failed validation: ${filePath.s3Key}');
      }

      _logInfo('✅ Generated S3 path: ${filePath.s3Key}');
      return filePath.s3Key;
    } catch (e) {
      _logError('❌ PersistentFileService path generation failed: $e');
      rethrow;
    }
  }

  /// Get the persistent User Pool sub identifier for the current authenticated user
  /// This identifier remains constant across app reinstalls and device changes
  ///
  /// Returns the User Pool sub identifier
  /// Throws [UserPoolSubException] if user is not authenticated or sub cannot be retrieved
  Future<String> getUserPoolSub() async {
    _logInfo('🔑 PersistentFileService: Retrieving User Pool sub');

    try {
      // Check cache first
      if (_cachedUserPoolSub != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration) {
        // Validate cached User Pool sub for integrity
        final cachedValidation =
            _dataValidator.validateUserPoolSub(_cachedUserPoolSub!);
        if (cachedValidation.isValid) {
          _logInfo('✅ Using cached User Pool sub');
          return _cachedUserPoolSub!;
        } else {
          _logWarning('⚠️ Cached User Pool sub failed validation, refreshing');
          // Clear invalid cache
          _cachedUserPoolSub = null;
          _cacheTimestamp = null;
        }
      }

      // Validate current user authentication state
      final authValidation =
          await _dataValidator.validateCurrentUserAuthentication();
      if (!authValidation.isValid) {
        final criticalIssues =
            authValidation.getIssuesByType(ValidationIssueType.critical);
        final securityIssues =
            authValidation.getIssuesByType(ValidationIssueType.security);
        final issues = [...criticalIssues, ...securityIssues];
        throw UserPoolSubException(
            'User authentication validation failed: ${issues.map((i) => i.message).join(', ')}');
      }

      // Get current authenticated user
      final user = await Amplify.Auth.getCurrentUser();

      // The userId is the User Pool sub (persistent identifier)
      final userPoolSub = user.userId;

      if (userPoolSub.isEmpty) {
        throw UserPoolSubException(
            'User Pool sub is empty - user may not be properly authenticated');
      }

      // Comprehensive User Pool sub validation using data integrity validator
      final userSubValidation = _dataValidator.validateUserPoolSub(userPoolSub);
      if (!userSubValidation.isValid) {
        final criticalIssues =
            userSubValidation.getIssuesByType(ValidationIssueType.critical);
        final securityIssues =
            userSubValidation.getIssuesByType(ValidationIssueType.security);
        final issues = [...criticalIssues, ...securityIssues];
        throw UserPoolSubException(
            'User Pool sub validation failed: ${issues.map((i) => i.message).join(', ')}');
      }

      // Log any warnings
      final warnings =
          userSubValidation.getIssuesByType(ValidationIssueType.warning);
      for (final warning in warnings) {
        _logWarning('⚠️ User Pool sub warning: ${warning.message}');
      }

      // Cache the validated User Pool sub
      _cachedUserPoolSub = userPoolSub;
      _cacheTimestamp = DateTime.now();

      _logInfo(
          '✅ Retrieved and validated User Pool sub: ${userPoolSub.substring(0, 8)}...');
      return userPoolSub;
    } catch (e) {
      _logError('❌ PersistentFileService getUserPoolSub failed: $e');
      throw FileOperationErrorHandler.handleError(
          e is Exception ? e : Exception(e.toString()));
    }
  }

  /// Migration support

  /// Migrate existing user to User Pool sub-based file paths
  /// This is the main entry point for user migration during first login after deployment
  /// Automatically detects if user has legacy files and migrates them seamlessly
  ///
  /// [forceReMigration] - If true, re-migrates files even if already migrated
  ///
  /// Returns a map with migration results and status
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<Map<String, dynamic>> migrateExistingUser(
      {bool forceReMigration = false}) async {
    _logInfo(
        '🔄 PersistentFileService: Starting existing user migration (force: $forceReMigration)');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to perform migration');
      }

      // Check if user has legacy files
      final hasLegacyFiles = await _hasLegacyFiles();

      if (!hasLegacyFiles && !forceReMigration) {
        _logInfo('✅ No legacy files detected - user is already migrated');
        return {
          'migrationNeeded': false,
          'migrationPerformed': false,
          'reason': 'no_legacy_files',
          'totalFiles': 0,
          'migratedFiles': 0,
          'failedFiles': 0,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Get migration status to check if already migrated
      if (!forceReMigration) {
        final status = await getMigrationStatus();
        if (status['migrationComplete'] == true) {
          _logInfo('✅ User files already migrated');
          return {
            'migrationNeeded': false,
            'migrationPerformed': false,
            'reason': 'already_migrated',
            'totalFiles': status['totalLegacyFiles'],
            'migratedFiles': status['migratedFiles'],
            'failedFiles': 0,
            'timestamp': DateTime.now().toIso8601String(),
          };
        }
      }

      // Perform migration
      _logInfo('🔄 Starting user file migration...');
      final startTime = DateTime.now();

      try {
        await migrateUserFiles();

        // Get final migration status
        final finalStatus = await getMigrationStatus();
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);

        _logInfo('✅ User migration completed in ${duration.inSeconds} seconds');

        return {
          'migrationNeeded': true,
          'migrationPerformed': true,
          'success': finalStatus['migrationComplete'],
          'totalFiles': finalStatus['totalLegacyFiles'],
          'migratedFiles': finalStatus['migratedFiles'],
          'failedFiles': finalStatus['pendingFiles'],
          'durationSeconds': duration.inSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } catch (e) {
        _logError('❌ User migration failed: $e');

        // Get current status even after failure
        final currentStatus = await getMigrationStatus();

        return {
          'migrationNeeded': true,
          'migrationPerformed': true,
          'success': false,
          'error': e.toString(),
          'totalFiles': currentStatus['totalLegacyFiles'],
          'migratedFiles': currentStatus['migratedFiles'],
          'failedFiles': currentStatus['pendingFiles'],
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      _logError('❌ migrateExistingUser failed: $e');
      return {
        'migrationNeeded': false,
        'migrationPerformed': false,
        'success': false,
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Check if user needs migration (has legacy files)
  /// This is a lightweight check that can be called during login
  ///
  /// Returns true if user has legacy files that need migration
  Future<bool> needsMigration() async {
    _logInfo('🔍 PersistentFileService: Checking if user needs migration');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        _logWarning('⚠️ User not authenticated - cannot check migration need');
        return false;
      }

      // Check if user has legacy files
      final hasLegacy = await _hasLegacyFiles();

      if (!hasLegacy) {
        _logInfo('✅ No legacy files - migration not needed');
        return false;
      }

      // Check if migration is already complete
      final status = await getMigrationStatus();
      final migrationComplete = status['migrationComplete'] == true;

      if (migrationComplete) {
        _logInfo('✅ Migration already complete');
        return false;
      }

      _logInfo('⚠️ User has legacy files that need migration');
      return true;
    } catch (e) {
      _logError('❌ Error checking migration need: $e');
      return false;
    }
  }

  /// Lightweight check for legacy files existence
  /// Returns true if user has any legacy files
  Future<bool> _hasLegacyFiles() async {
    try {
      final legacyFiles = await findLegacyFiles();
      return legacyFiles.isNotEmpty;
    } catch (e) {
      _logError('❌ Error checking for legacy files: $e');
      return false;
    }
  }

  /// Generate FilePath object using User Pool sub and private access level
  /// Returns a FilePath object with all necessary components
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file
  ///
  /// Returns a FilePath object with generated S3 path
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  /// Throws [FilePathGenerationException] if path generation fails
  Future<FilePath> generateFilePath(String syncId, String fileName) async {
    _logInfo(
        '📍 PersistentFileService: Generating FilePath for syncId: $syncId, fileName: $fileName');

    try {
      // Validate inputs
      _validatePathInputs(syncId, fileName);

      final userSub = await getUserPoolSub();

      // Validate User Pool sub using data integrity validator
      final userSubValidation = _dataValidator.validateUserPoolSub(userSub);
      if (!userSubValidation.isValid) {
        final criticalIssues =
            userSubValidation.getIssuesByType(ValidationIssueType.critical);
        final securityIssues =
            userSubValidation.getIssuesByType(ValidationIssueType.security);
        final issues = [...criticalIssues, ...securityIssues];
        throw FilePathGenerationException(
            'User Pool sub validation failed: ${issues.map((i) => i.message).join(', ')}');
      }

      // Create FilePath object
      final filePath = FilePath.create(
        userSub: userSub,
        syncId: syncId,
        fileName: fileName,
      );

      // Validate the created FilePath using data integrity validator
      final pathValidation = _dataValidator.validateFilePath(filePath);
      if (!pathValidation.isValid) {
        // Try to correct the path if possible
        final correctionResult =
            _dataValidator.validateAndCorrectFilePath(filePath);

        if (correctionResult.isValid) {
          _logInfo(
              '🔧 Applied path corrections: ${correctionResult.appliedFixes.join(', ')}');
          _logInfo(
              '✅ Generated corrected FilePath: ${correctionResult.correctedPath.s3Key}');
          return correctionResult.correctedPath;
        } else {
          final criticalIssues =
              pathValidation.getIssuesByType(ValidationIssueType.critical);
          final securityIssues =
              pathValidation.getIssuesByType(ValidationIssueType.security);
          final issues = [...criticalIssues, ...securityIssues];
          throw FilePathGenerationException(
              'FilePath validation failed: ${issues.map((i) => i.message).join(', ')}');
        }
      }

      _logInfo('✅ Generated FilePath: ${filePath.s3Key}');
      return filePath;
    } catch (e) {
      _logError('❌ PersistentFileService FilePath generation failed: $e');
      rethrow;
    }
  }

  /// Generate S3 directory path for a user and sync ID
  /// Format: private/{userSub}/documents/{syncId}/
  ///
  /// [syncId] - Sync identifier for organizing files
  ///
  /// Returns the S3 directory path
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<String> generateS3DirectoryPath(String syncId) async {
    _logInfo(
        '📁 PersistentFileService: Generating S3 directory path for syncId: $syncId');

    try {
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      final userSub = await getUserPoolSub();
      final directoryPath = 'private/$userSub/documents/$syncId/';

      _logInfo('✅ Generated directory path: $directoryPath');
      return directoryPath;
    } catch (e) {
      _logError('❌ Directory path generation failed: $e');
      rethrow;
    }
  }

  /// Generate S3 path with custom timestamp
  /// Useful for testing or when specific timestamp is needed
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file
  /// [timestamp] - Custom timestamp to use
  ///
  /// Returns the S3 path with custom timestamp
  Future<String> generateS3PathWithTimestamp(
      String syncId, String fileName, int timestamp) async {
    _logInfo(
        '📍 PersistentFileService: Generating S3 path with custom timestamp');

    try {
      _validatePathInputs(syncId, fileName);

      final userSub = await getUserPoolSub();

      final filePath = FilePath.create(
        userSub: userSub,
        syncId: syncId,
        fileName: fileName,
        timestamp: timestamp,
      );

      _logInfo('✅ Generated S3 path with timestamp: ${filePath.s3Key}');
      return filePath.s3Key;
    } catch (e) {
      _logError('❌ S3 path generation with timestamp failed: $e');
      rethrow;
    }
  }

  /// Parse an existing S3 key to extract components
  /// Returns a FilePath object if the key is valid
  ///
  /// [s3Key] - The S3 key to parse
  ///
  /// Returns FilePath object with extracted components
  /// Throws [FilePathGenerationException] if S3 key format is invalid
  FilePath parseS3Key(String s3Key) {
    _logInfo('🔍 PersistentFileService: Parsing S3 key: $s3Key');

    try {
      final filePath = FilePath.fromS3Key(s3Key);

      if (!filePath.validate()) {
        throw FilePathGenerationException(
            'Parsed S3 key failed validation: $s3Key');
      }

      _logInfo('✅ Successfully parsed S3 key');
      return filePath;
    } catch (e) {
      _logError('❌ S3 key parsing failed: $e');
      rethrow;
    }
  }

  /// Validate that an S3 key belongs to the current user
  /// Checks if the User Pool sub in the path matches the current user
  ///
  /// [s3Key] - The S3 key to validate
  ///
  /// Returns true if the key belongs to the current user
  Future<bool> validateS3KeyOwnership(String s3Key) async {
    _logInfo('🔒 PersistentFileService: Validating S3 key ownership');

    try {
      final currentUserSub = await getUserPoolSub();
      final extractedUserSub = UserPoolSubValidator.extractFromS3Path(s3Key);

      if (extractedUserSub == null) {
        _logWarning('⚠️ Could not extract User Pool sub from S3 key: $s3Key');
        return false;
      }

      final isOwner = extractedUserSub == currentUserSub;
      _logInfo('✅ S3 key ownership validation: $isOwner');
      return isOwner;
    } catch (e) {
      _logError('❌ S3 key ownership validation failed: $e');
      return false;
    }
  }

  /// Generate multiple S3 paths for batch operations
  /// Useful for uploading multiple files with the same sync ID
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileNames] - List of file names to generate paths for
  ///
  /// Returns a map of fileName -> S3 path
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  /// Throws [FilePathGenerationException] if any path generation fails
  Future<Map<String, String>> generateMultipleS3Paths(
      String syncId, List<String> fileNames) async {
    _logInfo(
        '📍 PersistentFileService: Generating ${fileNames.length} S3 paths for syncId: $syncId');

    try {
      if (fileNames.isEmpty) {
        return {};
      }

      final results = <String, String>{};

      // Get User Pool sub once for all paths
      final userSub = await getUserPoolSub();

      for (final fileName in fileNames) {
        _validatePathInputs(syncId, fileName);

        final filePath = FilePath.create(
          userSub: userSub,
          syncId: syncId,
          fileName: fileName,
        );

        results[fileName] = filePath.s3Key;
      }

      _logInfo('✅ Generated ${results.length} S3 paths');
      return results;
    } catch (e) {
      _logError('❌ Multiple S3 path generation failed: $e');
      rethrow;
    }
  }

  /// Migration support

  /// Migrate existing user files from legacy path structure to User Pool sub-based paths
  /// This ensures backward compatibility for existing users
  ///
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<void> migrateUserFiles() async {
    _logInfo('🔄 PersistentFileService: Starting user file migration');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to migrate files');
      }

      // Get detailed inventory of legacy files
      final inventory = await getLegacyFileInventory();

      if (inventory.isEmpty) {
        _logInfo('📭 No legacy files found - migration not needed');
        return;
      }

      _logInfo('🔄 Starting migration of ${inventory.length} legacy files');

      // Validate all migration mappings before starting
      final validMappings = <FileMigrationMapping>[];
      final invalidMappings = <FileMigrationMapping>[];

      for (final mapping in inventory) {
        final validationResult =
            _dataValidator.validateMigrationMapping(mapping);
        if (validationResult.isValid) {
          validMappings.add(mapping);
        } else {
          invalidMappings.add(mapping);
          final criticalIssues =
              validationResult.getIssuesByType(ValidationIssueType.critical);
          final securityIssues =
              validationResult.getIssuesByType(ValidationIssueType.security);
          final issues = [...criticalIssues, ...securityIssues];
          _logError(
              '❌ Invalid migration mapping for ${mapping.legacyPath}: ${issues.map((i) => i.message).join(', ')}');
        }
      }

      if (invalidMappings.isNotEmpty) {
        _logWarning(
            '⚠️ Found ${invalidMappings.length} invalid migration mappings, skipping them');
      }

      if (validMappings.isEmpty) {
        _logError('❌ No valid migration mappings found');
        return;
      }

      _logInfo(
          '🔄 Processing ${validMappings.length} valid migration mappings');

      int successCount = 0;
      int failureCount = 0;
      final failedMigrations = <String>[];

      // Process each valid file migration
      for (final mapping in validMappings) {
        try {
          final success = await _migrateSingleFile(mapping);
          if (success) {
            successCount++;
            _logInfo(
                '✅ Successfully migrated: ${mapping.legacyPath} -> ${mapping.newPath}');
          } else {
            failureCount++;
            failedMigrations.add(mapping.legacyPath);
            _logError('❌ Failed to migrate: ${mapping.legacyPath}');
          }
        } catch (e) {
          failureCount++;
          failedMigrations.add(mapping.legacyPath);
          _logError('❌ Error migrating ${mapping.legacyPath}: $e');
        }
      }

      // Log migration summary
      _logInfo(
          '📊 Migration completed: $successCount successful, $failureCount failed');

      if (failedMigrations.isNotEmpty) {
        _logWarning('⚠️ Failed migrations: ${failedMigrations.join(', ')}');
        throw FilePathGenerationException(
            'Migration completed with ${failedMigrations.length} failures. Failed files: ${failedMigrations.join(', ')}');
      }

      _logInfo('🎉 All files migrated successfully!');
    } catch (e) {
      _logError('❌ PersistentFileService migration failed: $e');
      rethrow;
    }
  }

  /// Migrate files for a specific sync ID only
  /// Useful for targeted migration of specific document sets
  ///
  /// [syncId] - The sync identifier to migrate files for
  ///
  /// Returns the number of files successfully migrated
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<int> migrateFilesForSyncId(String syncId) async {
    _logInfo(
        '🔄 PersistentFileService: Starting migration for sync ID: $syncId');

    try {
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to migrate files');
      }

      // Get legacy files for the specific sync ID
      final legacyFiles = await getLegacyFilesForSyncId(syncId);

      if (legacyFiles.isEmpty) {
        _logInfo('📭 No legacy files found for sync ID: $syncId');
        return 0;
      }

      _logInfo(
          '🔄 Starting migration of ${legacyFiles.length} files for sync ID: $syncId');

      int successCount = 0;
      final userSub = await getUserPoolSub();

      // Process each file
      for (final legacyPath in legacyFiles) {
        try {
          final fileName = _extractFileNameFromLegacyPath(legacyPath);
          if (fileName != null) {
            final newPath = await generateS3Path(syncId, fileName);

            final mapping = FileMigrationMapping.create(
              legacyPath: legacyPath,
              newPath: newPath,
              userSub: userSub,
              syncId: syncId,
              fileName: fileName,
            );

            final success = await _migrateSingleFile(mapping);
            if (success) {
              successCount++;
              _logInfo('✅ Successfully migrated: $legacyPath -> $newPath');
            } else {
              _logError('❌ Failed to migrate: $legacyPath');
            }
          } else {
            _logWarning('⚠️ Could not extract filename from: $legacyPath');
          }
        } catch (e) {
          _logError('❌ Error migrating $legacyPath: $e');
        }
      }

      _logInfo(
          '📊 Migration for sync ID $syncId completed: $successCount/${legacyFiles.length} successful');
      return successCount;
    } catch (e) {
      _logError('❌ Migration for sync ID $syncId failed: $e');
      rethrow;
    }
  }

  /// Verify that a file migration was successful
  /// Checks that the new file exists and has the same content as the legacy file
  ///
  /// [mapping] - The migration mapping to verify
  ///
  /// Returns true if migration was successful
  Future<bool> verifyMigration(FileMigrationMapping mapping) async {
    _logInfo(
        '🔍 Verifying migration: ${mapping.legacyPath} -> ${mapping.newPath}');

    try {
      // Check that the new file exists
      final newFileExists = await _fileExists(mapping.newPath);
      if (!newFileExists) {
        _logError('❌ New file does not exist: ${mapping.newPath}');
        return false;
      }

      // Check that the legacy file still exists (for comparison)
      final legacyFileExists = await _fileExists(mapping.legacyPath);
      if (!legacyFileExists) {
        _logWarning('⚠️ Legacy file no longer exists: ${mapping.legacyPath}');
        // This might be okay if the file was already cleaned up
        return true;
      }

      // Get properties of both files for comparison
      try {
        final newFileProps = await Amplify.Storage.getProperties(
          path: StoragePath.fromString(mapping.newPath),
        ).result;

        final legacyFileProps = await Amplify.Storage.getProperties(
          path: StoragePath.fromString(mapping.legacyPath),
        ).result;

        // Compare file sizes
        if (newFileProps.storageItem.size != legacyFileProps.storageItem.size) {
          _logError(
              '❌ File size mismatch: new=${newFileProps.storageItem.size}, legacy=${legacyFileProps.storageItem.size}');
          return false;
        }

        _logInfo('✅ Migration verified successfully: ${mapping.newPath}');
        return true;
      } on StorageException catch (e) {
        _logError('❌ Error comparing file properties: ${e.message}');
        return false;
      }
    } catch (e) {
      _logError('❌ Error verifying migration: $e');
      return false;
    }
  }

  /// Get migration status for all legacy files
  /// Returns a summary of which files have been migrated and which haven't
  ///
  /// Returns a map with migration status information
  Future<Map<String, dynamic>> getMigrationStatus() async {
    _logInfo('📊 Getting migration status');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to check migration status');
      }

      final inventory = await getLegacyFileInventory();

      if (inventory.isEmpty) {
        return {
          'totalLegacyFiles': 0,
          'migratedFiles': 0,
          'pendingFiles': 0,
          'migrationComplete': true,
          'legacyFilesList': <String>[],
          'migratedFilesList': <String>[],
          'pendingFilesList': <String>[],
        };
      }

      final migratedFiles = <String>[];
      final pendingFiles = <String>[];

      // Check each file's migration status
      for (final mapping in inventory) {
        final newFileExists = await _fileExists(mapping.newPath);
        if (newFileExists) {
          migratedFiles.add(mapping.legacyPath);
        } else {
          pendingFiles.add(mapping.legacyPath);
        }
      }

      final migrationComplete = pendingFiles.isEmpty;

      _logInfo(
          '📊 Migration status: ${migratedFiles.length}/${inventory.length} files migrated');

      return {
        'totalLegacyFiles': inventory.length,
        'migratedFiles': migratedFiles.length,
        'pendingFiles': pendingFiles.length,
        'migrationComplete': migrationComplete,
        'legacyFilesList': inventory.map((m) => m.legacyPath).toList(),
        'migratedFilesList': migratedFiles,
        'pendingFilesList': pendingFiles,
      };
    } catch (e) {
      _logError('❌ Error getting migration status: $e');
      rethrow;
    }
  }

  /// Rollback migration for all files
  /// Removes migrated files from new paths, keeping only legacy files
  ///
  /// Returns the number of files successfully rolled back
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<int> rollbackMigration() async {
    _logInfo('🔄 PersistentFileService: Starting migration rollback');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to rollback migration');
      }

      final inventory = await getLegacyFileInventory();

      if (inventory.isEmpty) {
        _logInfo('📭 No legacy files found - rollback not needed');
        return 0;
      }

      _logInfo(
          '🔄 Starting rollback of ${inventory.length} potential migrations');

      int rollbackCount = 0;
      final failedRollbacks = <String>[];

      // Process each potential migration
      for (final mapping in inventory) {
        try {
          // Check if the new file exists (was migrated)
          final newFileExists = await _fileExists(mapping.newPath);
          if (newFileExists) {
            // Check if legacy file still exists
            final legacyFileExists = await _fileExists(mapping.legacyPath);
            if (legacyFileExists) {
              // Delete the new file to rollback
              final success = await _deleteFileIfExists(mapping.newPath);
              if (success) {
                rollbackCount++;
                _logInfo('✅ Rolled back: ${mapping.newPath}');
              } else {
                failedRollbacks.add(mapping.newPath);
                _logError('❌ Failed to rollback: ${mapping.newPath}');
              }
            } else {
              _logWarning(
                  '⚠️ Legacy file missing, cannot rollback: ${mapping.legacyPath}');
            }
          } else {
            _logInfo(
                '📭 File not migrated, no rollback needed: ${mapping.newPath}');
          }
        } catch (e) {
          failedRollbacks.add(mapping.newPath);
          _logError('❌ Error rolling back ${mapping.newPath}: $e');
        }
      }

      // Log rollback summary
      _logInfo(
          '📊 Rollback completed: $rollbackCount successful, ${failedRollbacks.length} failed');

      if (failedRollbacks.isNotEmpty) {
        _logWarning('⚠️ Failed rollbacks: ${failedRollbacks.join(', ')}');
      }

      return rollbackCount;
    } catch (e) {
      _logError('❌ Migration rollback failed: $e');
      rethrow;
    }
  }

  /// Rollback migration for a specific sync ID
  /// Removes migrated files for the sync ID from new paths
  ///
  /// [syncId] - The sync identifier to rollback migration for
  ///
  /// Returns the number of files successfully rolled back
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<int> rollbackMigrationForSyncId(String syncId) async {
    _logInfo(
        '🔄 PersistentFileService: Rolling back migration for sync ID: $syncId');

    try {
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to rollback migration');
      }

      // Get legacy files for the specific sync ID
      final legacyFiles = await getLegacyFilesForSyncId(syncId);

      if (legacyFiles.isEmpty) {
        _logInfo('📭 No legacy files found for sync ID: $syncId');
        return 0;
      }

      _logInfo(
          '🔄 Starting rollback of ${legacyFiles.length} files for sync ID: $syncId');

      int rollbackCount = 0;

      // Process each file
      for (final legacyPath in legacyFiles) {
        try {
          final fileName = _extractFileNameFromLegacyPath(legacyPath);
          if (fileName != null) {
            final newPath = await generateS3Path(syncId, fileName);

            // Check if the new file exists (was migrated)
            final newFileExists = await _fileExists(newPath);
            if (newFileExists) {
              // Delete the new file to rollback
              final success = await _deleteFileIfExists(newPath);
              if (success) {
                rollbackCount++;
                _logInfo('✅ Rolled back: $newPath');
              } else {
                _logError('❌ Failed to rollback: $newPath');
              }
            } else {
              _logInfo('📭 File not migrated, no rollback needed: $newPath');
            }
          } else {
            _logWarning('⚠️ Could not extract filename from: $legacyPath');
          }
        } catch (e) {
          _logError('❌ Error rolling back $legacyPath: $e');
        }
      }

      _logInfo(
          '📊 Rollback for sync ID $syncId completed: $rollbackCount files rolled back');
      return rollbackCount;
    } catch (e) {
      _logError('❌ Rollback for sync ID $syncId failed: $e');
      rethrow;
    }
  }

  /// Download file with fallback to legacy path
  /// Tries new User Pool sub-based path first, falls back to legacy path if needed
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file to download
  ///
  /// Returns the local path where the file was downloaded
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  /// Throws [FilePathGenerationException] if file not found in either location
  Future<String> downloadFileWithFallback(
      String syncId, String fileName) async {
    _logInfo(
        '📥 PersistentFileService: Downloading file with fallback - syncId: $syncId, fileName: $fileName');

    try {
      // Validate inputs
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }
      if (fileName.isEmpty) {
        throw FilePathGenerationException('File name cannot be empty');
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to download files');
      }

      // Try new User Pool sub-based path first
      try {
        final newS3Key = await generateS3Path(syncId, fileName);
        final newFileExists = await _fileExists(newS3Key);

        if (newFileExists) {
          _logInfo('✅ Found file in new path: $newS3Key');
          return await downloadFile(newS3Key, syncId);
        }
      } catch (e) {
        _logWarning('⚠️ Error checking new path: $e');
      }

      // Fallback to legacy path
      _logInfo('🔄 Falling back to legacy path for file: $fileName');

      final user = await Amplify.Auth.getCurrentUser();
      final username = user.username;

      if (username.isEmpty) {
        throw FilePathGenerationException(
            'Username is empty - cannot access legacy files');
      }

      // Generate legacy path
      final legacyS3Key = 'protected/$username/documents/$syncId/$fileName';
      final legacyFileExists = await _fileExists(legacyS3Key);

      if (legacyFileExists) {
        _logInfo('✅ Found file in legacy path: $legacyS3Key');
        return await _downloadLegacyFile(legacyS3Key, syncId, fileName);
      }

      // File not found in either location
      throw FilePathGenerationException(
          'File not found in new or legacy paths: syncId=$syncId, fileName=$fileName');
    } catch (e) {
      _logError('❌ Download with fallback failed: $e');
      rethrow;
    }
  }

  /// Check if file exists with fallback to legacy path
  /// Checks new User Pool sub-based path first, then legacy path
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file to check
  ///
  /// Returns true if file exists in either location
  Future<bool> fileExistsWithFallback(String syncId, String fileName) async {
    _logInfo(
        '🔍 Checking file existence with fallback - syncId: $syncId, fileName: $fileName');

    try {
      // Validate inputs
      if (syncId.isEmpty || fileName.isEmpty) {
        return false;
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        return false;
      }

      // Check new User Pool sub-based path first
      try {
        final newS3Key = await generateS3Path(syncId, fileName);
        final newFileExists = await _fileExists(newS3Key);

        if (newFileExists) {
          _logInfo('✅ File exists in new path: $newS3Key');
          return true;
        }
      } catch (e) {
        _logWarning('⚠️ Error checking new path: $e');
      }

      // Check legacy path
      try {
        final user = await Amplify.Auth.getCurrentUser();
        final username = user.username;

        if (username.isNotEmpty) {
          final legacyS3Key = 'protected/$username/documents/$syncId/$fileName';
          final legacyFileExists = await _fileExists(legacyS3Key);

          if (legacyFileExists) {
            _logInfo('✅ File exists in legacy path: $legacyS3Key');
            return true;
          }
        }
      } catch (e) {
        _logWarning('⚠️ Error checking legacy path: $e');
      }

      _logInfo(
          '📭 File not found in either path: syncId=$syncId, fileName=$fileName');
      return false;
    } catch (e) {
      _logError('❌ Error checking file existence with fallback: $e');
      return false;
    }
  }

  /// Backward Compatibility and Validation

  /// Validate file access for pre-migration files
  /// Checks if a file is accessible in either new or legacy path
  /// Returns detailed validation information
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file to validate
  ///
  /// Returns a map with validation details
  Future<Map<String, dynamic>> validateFileAccess(
      String syncId, String fileName) async {
    _logInfo(
        '🔍 PersistentFileService: Validating file access for syncId: $syncId, fileName: $fileName');

    try {
      // Validate inputs
      if (syncId.isEmpty || fileName.isEmpty) {
        return {
          'accessible': false,
          'reason': 'invalid_inputs',
          'newPathExists': false,
          'legacyPathExists': false,
          'migrationStatus': 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        return {
          'accessible': false,
          'reason': 'not_authenticated',
          'newPathExists': false,
          'legacyPathExists': false,
          'migrationStatus': 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Check new User Pool sub-based path
      bool newPathExists = false;
      String? newPath;
      try {
        newPath = await generateS3Path(syncId, fileName);
        newPathExists = await _fileExists(newPath);
      } catch (e) {
        _logWarning('⚠️ Error checking new path: $e');
      }

      // Check legacy username-based path
      bool legacyPathExists = false;
      String? legacyPath;
      try {
        final user = await Amplify.Auth.getCurrentUser();
        final username = user.username;
        if (username.isNotEmpty) {
          legacyPath = 'protected/$username/documents/$syncId/$fileName';
          legacyPathExists = await _fileExists(legacyPath);
        }
      } catch (e) {
        _logWarning('⚠️ Error checking legacy path: $e');
      }

      // Determine migration status
      String migrationStatus;
      if (newPathExists && !legacyPathExists) {
        migrationStatus = 'migrated';
      } else if (!newPathExists && legacyPathExists) {
        migrationStatus = 'pending';
      } else if (newPathExists && legacyPathExists) {
        migrationStatus = 'in_progress';
      } else {
        migrationStatus = 'not_found';
      }

      final accessible = newPathExists || legacyPathExists;

      _logInfo(
          '✅ File access validation complete: accessible=$accessible, status=$migrationStatus');

      return {
        'accessible': accessible,
        'reason': accessible ? 'file_found' : 'file_not_found',
        'newPathExists': newPathExists,
        'legacyPathExists': legacyPathExists,
        'newPath': newPath,
        'legacyPath': legacyPath,
        'migrationStatus': migrationStatus,
        'recommendedAction': _getRecommendedAction(migrationStatus),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logError('❌ Error validating file access: $e');
      return {
        'accessible': false,
        'reason': 'validation_error',
        'error': e.toString(),
        'newPathExists': false,
        'legacyPathExists': false,
        'migrationStatus': 'error',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get recommended action based on migration status
  String _getRecommendedAction(String migrationStatus) {
    switch (migrationStatus) {
      case 'migrated':
        return 'use_new_path';
      case 'pending':
        return 'migrate_file';
      case 'in_progress':
        return 'verify_migration';
      case 'not_found':
        return 'file_missing';
      default:
        return 'unknown';
    }
  }

  /// Verify post-migration file access
  /// Ensures that migrated files are accessible via new path
  /// and optionally validates content integrity
  ///
  /// [syncId] - Sync identifier for organizing files
  /// [fileName] - Name of the file to verify
  /// [validateContent] - Whether to validate file content integrity
  ///
  /// Returns a map with verification results
  Future<Map<String, dynamic>> verifyPostMigrationAccess(
    String syncId,
    String fileName, {
    bool validateContent = false,
  }) async {
    _logInfo(
        '🔍 PersistentFileService: Verifying post-migration access for syncId: $syncId, fileName: $fileName');

    try {
      // Validate inputs
      if (syncId.isEmpty || fileName.isEmpty) {
        return {
          'verified': false,
          'reason': 'invalid_inputs',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        return {
          'verified': false,
          'reason': 'not_authenticated',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Check if file exists in new path
      final newPath = await generateS3Path(syncId, fileName);
      final newPathExists = await _fileExists(newPath);

      if (!newPathExists) {
        _logWarning('⚠️ File not found in new path: $newPath');
        return {
          'verified': false,
          'reason': 'file_not_in_new_path',
          'newPath': newPath,
          'newPathExists': false,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Get file properties from new path
      Map<String, dynamic>? newFileProperties;
      try {
        final properties = await Amplify.Storage.getProperties(
          path: StoragePath.fromString(newPath),
        ).result;

        newFileProperties = {
          'size': properties.storageItem.size,
          'lastModified':
              properties.storageItem.lastModified?.toIso8601String(),
          'eTag': properties.storageItem.eTag,
        };
      } catch (e) {
        _logWarning('⚠️ Could not get file properties: $e');
      }

      // Check if legacy file still exists
      bool legacyPathExists = false;
      String? legacyPath;
      Map<String, dynamic>? legacyFileProperties;

      try {
        final user = await Amplify.Auth.getCurrentUser();
        final username = user.username;
        if (username.isNotEmpty) {
          legacyPath = 'protected/$username/documents/$syncId/$fileName';
          legacyPathExists = await _fileExists(legacyPath);

          if (legacyPathExists && validateContent) {
            final legacyProperties = await Amplify.Storage.getProperties(
              path: StoragePath.fromString(legacyPath),
            ).result;

            legacyFileProperties = {
              'size': legacyProperties.storageItem.size,
              'lastModified':
                  legacyProperties.storageItem.lastModified?.toIso8601String(),
              'eTag': legacyProperties.storageItem.eTag,
            };
          }
        }
      } catch (e) {
        _logWarning('⚠️ Error checking legacy path: $e');
      }

      // Validate content integrity if requested
      bool contentValid = true;
      String? contentValidationMessage;

      if (validateContent &&
          newFileProperties != null &&
          legacyFileProperties != null) {
        // Compare file sizes
        if (newFileProperties['size'] != legacyFileProperties['size']) {
          contentValid = false;
          contentValidationMessage =
              'File size mismatch: new=${newFileProperties['size']}, legacy=${legacyFileProperties['size']}';
        }
      }

      final verified = newPathExists && contentValid;

      _logInfo('✅ Post-migration access verification: verified=$verified');

      return {
        'verified': verified,
        'reason': verified ? 'access_verified' : 'verification_failed',
        'newPath': newPath,
        'newPathExists': newPathExists,
        'newFileProperties': newFileProperties,
        'legacyPath': legacyPath,
        'legacyPathExists': legacyPathExists,
        'legacyFileProperties': legacyFileProperties,
        'contentValid': contentValid,
        'contentValidationMessage': contentValidationMessage,
        'migrationComplete': newPathExists && !legacyPathExists,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logError('❌ Error verifying post-migration access: $e');
      return {
        'verified': false,
        'reason': 'verification_error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Get dual-path access status for all files in a sync ID
  /// Useful for monitoring migration progress and ensuring backward compatibility
  ///
  /// [syncId] - Sync identifier to check
  ///
  /// Returns a map with dual-path access status
  Future<Map<String, dynamic>> getDualPathAccessStatus(String syncId) async {
    _logInfo(
        '📊 PersistentFileService: Getting dual-path access status for syncId: $syncId');

    try {
      // Validate inputs
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to check dual-path access status');
      }

      // Get legacy files for this sync ID
      final legacyFiles = await getLegacyFilesForSyncId(syncId);

      final fileStatuses = <Map<String, dynamic>>[];
      int newPathCount = 0;
      int legacyPathCount = 0;
      int bothPathsCount = 0;
      int migratedCount = 0;

      for (final legacyPath in legacyFiles) {
        final fileName = _extractFileNameFromLegacyPath(legacyPath);
        if (fileName != null) {
          final validation = await validateFileAccess(syncId, fileName);

          fileStatuses.add({
            'fileName': fileName,
            'accessible': validation['accessible'],
            'newPathExists': validation['newPathExists'],
            'legacyPathExists': validation['legacyPathExists'],
            'migrationStatus': validation['migrationStatus'],
          });

          if (validation['newPathExists'] == true) newPathCount++;
          if (validation['legacyPathExists'] == true) legacyPathCount++;
          if (validation['newPathExists'] == true &&
              validation['legacyPathExists'] == true) {
            bothPathsCount++;
          }
          if (validation['migrationStatus'] == 'migrated') migratedCount++;
        }
      }

      final totalFiles = legacyFiles.length;
      final migrationProgress =
          totalFiles > 0 ? ((migratedCount / totalFiles) * 100).round() : 100;

      _logInfo(
          '📊 Dual-path access status: $migratedCount/$totalFiles migrated ($migrationProgress%)');

      return {
        'syncId': syncId,
        'totalFiles': totalFiles,
        'newPathCount': newPathCount,
        'legacyPathCount': legacyPathCount,
        'bothPathsCount': bothPathsCount,
        'migratedCount': migratedCount,
        'migrationProgress': migrationProgress,
        'dualPathAccessActive': bothPathsCount > 0,
        'fileStatuses': fileStatuses,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logError('❌ Error getting dual-path access status: $e');
      rethrow;
    }
  }

  /// Validate backward compatibility for a batch of files
  /// Ensures all files are accessible during migration period
  ///
  /// [syncId] - Sync identifier for the files
  /// [fileNames] - List of file names to validate
  ///
  /// Returns a map with batch validation results
  Future<Map<String, dynamic>> validateBackwardCompatibility(
    String syncId,
    List<String> fileNames,
  ) async {
    _logInfo(
        '🔍 PersistentFileService: Validating backward compatibility for ${fileNames.length} files');

    try {
      // Validate inputs
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      if (fileNames.isEmpty) {
        return {
          'allAccessible': true,
          'totalFiles': 0,
          'accessibleFiles': 0,
          'inaccessibleFiles': 0,
          'fileValidations': <Map<String, dynamic>>[],
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to validate backward compatibility');
      }

      final validations = <Map<String, dynamic>>[];
      int accessibleCount = 0;
      int inaccessibleCount = 0;

      for (final fileName in fileNames) {
        final validation = await validateFileAccess(syncId, fileName);
        validations.add({
          'fileName': fileName,
          'accessible': validation['accessible'],
          'migrationStatus': validation['migrationStatus'],
          'newPathExists': validation['newPathExists'],
          'legacyPathExists': validation['legacyPathExists'],
        });

        if (validation['accessible'] == true) {
          accessibleCount++;
        } else {
          inaccessibleCount++;
        }
      }

      final allAccessible = inaccessibleCount == 0;

      _logInfo(
          '✅ Backward compatibility validation: $accessibleCount/${fileNames.length} accessible');

      return {
        'allAccessible': allAccessible,
        'totalFiles': fileNames.length,
        'accessibleFiles': accessibleCount,
        'inaccessibleFiles': inaccessibleCount,
        'fileValidations': validations,
        'backwardCompatible': allAccessible,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      _logError('❌ Error validating backward compatibility: $e');
      rethrow;
    }
  }

  /// Get migration progress tracking information
  /// Returns detailed progress information for monitoring
  ///
  /// Returns a map with detailed migration progress
  Future<Map<String, dynamic>> getMigrationProgress() async {
    _logInfo('📊 Getting detailed migration progress');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to check migration progress');
      }

      final inventory = await getLegacyFileInventory();

      if (inventory.isEmpty) {
        return {
          'status': 'no_legacy_files',
          'totalFiles': 0,
          'migratedFiles': 0,
          'pendingFiles': 0,
          'failedFiles': 0,
          'progressPercentage': 100,
          'migrationComplete': true,
          'canRollback': false,
          'details': <Map<String, dynamic>>[],
        };
      }

      final fileDetails = <Map<String, dynamic>>[];
      int migratedCount = 0;
      int pendingCount = 0;
      int failedCount = 0;

      // Check each file's detailed status
      for (final mapping in inventory) {
        final newFileExists = await _fileExists(mapping.newPath);
        final legacyFileExists = await _fileExists(mapping.legacyPath);

        String status;
        if (newFileExists && legacyFileExists) {
          status = 'migrated';
          migratedCount++;
        } else if (!newFileExists && legacyFileExists) {
          status = 'pending';
          pendingCount++;
        } else if (newFileExists && !legacyFileExists) {
          status = 'migrated_legacy_deleted';
          migratedCount++;
        } else {
          status = 'failed_missing_files';
          failedCount++;
        }

        fileDetails.add({
          'legacyPath': mapping.legacyPath,
          'newPath': mapping.newPath,
          'syncId': mapping.syncId,
          'fileName': mapping.fileName,
          'status': status,
          'newFileExists': newFileExists,
          'legacyFileExists': legacyFileExists,
        });
      }

      final totalFiles = inventory.length;
      final progressPercentage =
          totalFiles > 0 ? ((migratedCount / totalFiles) * 100).round() : 100;
      final migrationComplete = pendingCount == 0 && failedCount == 0;
      final canRollback = migratedCount > 0;

      String overallStatus;
      if (migrationComplete) {
        overallStatus = 'complete';
      } else if (migratedCount > 0) {
        overallStatus = 'in_progress';
      } else {
        overallStatus = 'not_started';
      }

      _logInfo(
          '📊 Migration progress: $migratedCount/$totalFiles migrated ($progressPercentage%)');

      return {
        'status': overallStatus,
        'totalFiles': totalFiles,
        'migratedFiles': migratedCount,
        'pendingFiles': pendingCount,
        'failedFiles': failedCount,
        'progressPercentage': progressPercentage,
        'migrationComplete': migrationComplete,
        'canRollback': canRollback,
        'details': fileDetails,
      };
    } catch (e) {
      _logError('❌ Error getting migration progress: $e');
      rethrow;
    }
  }

  /// Find legacy files that need to be migrated
  /// Returns a list of S3 keys for files using the old path structure
  ///
  /// Returns list of legacy file S3 keys
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<List<String>> findLegacyFiles() async {
    _logInfo('🔍 PersistentFileService: Finding legacy files for migration');

    try {
      // Validate user authentication
      if (!await isUserAuthenticated()) {
        throw UserPoolSubException(
            'User must be authenticated to find legacy files');
      }

      // Get current user information
      final user = await Amplify.Auth.getCurrentUser();
      final username = user.username;

      if (username.isEmpty) {
        _logWarning('⚠️ Username is empty - no legacy files to find');
        return [];
      }

      _logInfo(
          '🔍 Scanning for legacy files for username: ${username.substring(0, 3)}***');

      // List files in the legacy protected folder structure
      // Legacy format: protected/{username}/documents/
      final legacyBasePath = 'protected/$username/documents/';

      final legacyFiles = <String>[];

      try {
        // List all files in the legacy protected folder
        final listResult = await Amplify.Storage.list(
          path: StoragePath.fromString(legacyBasePath),
        ).result;

        _logInfo(
            '📋 Found ${listResult.items.length} items in legacy path: $legacyBasePath');

        // Process each item found
        for (final item in listResult.items) {
          final itemPath = item.path;

          // Validate that this is a file (not a folder) and follows legacy format
          if (_isValidLegacyFile(itemPath, username)) {
            legacyFiles.add(itemPath);
            _logInfo('✅ Found legacy file: $itemPath');
          } else {
            _logInfo('⚠️ Skipping invalid legacy item: $itemPath');
          }
        }

        _logInfo('🎯 Total legacy files found: ${legacyFiles.length}');

        // Sort files for consistent processing order
        legacyFiles.sort();

        return legacyFiles;
      } on StorageException catch (e) {
        if (e.message.contains('NoSuchKey') ||
            e.message.contains('not found')) {
          _logInfo(
              '📭 No legacy files found - user has no files in legacy path structure');
          return [];
        } else {
          _logError('❌ Storage error while listing legacy files: ${e.message}');
          throw FilePathGenerationException(
              'Failed to list legacy files: ${e.message}');
        }
      }
    } on AuthException catch (e) {
      _logError('❌ Authentication error finding legacy files: ${e.message}');
      throw UserPoolSubException('Authentication failed: ${e.message}');
    } catch (e) {
      _logError('❌ PersistentFileService findLegacyFiles failed: $e');
      rethrow;
    }
  }

  /// Get detailed inventory of legacy files with metadata
  /// Returns a list of FileMigrationMapping objects for each legacy file
  ///
  /// Returns list of migration mappings for legacy files
  /// Throws [UserPoolSubException] if User Pool sub cannot be retrieved
  Future<List<FileMigrationMapping>> getLegacyFileInventory() async {
    _logInfo(
        '📊 PersistentFileService: Creating detailed legacy file inventory');

    try {
      final legacyFiles = await findLegacyFiles();
      final inventory = <FileMigrationMapping>[];
      final userSub = await getUserPoolSub();

      for (final legacyPath in legacyFiles) {
        try {
          // Extract components from legacy path
          final syncId = _extractSyncIdFromLegacyPath(legacyPath);
          final fileName = _extractFileNameFromLegacyPath(legacyPath);

          if (syncId != null && fileName != null) {
            // Generate the new path using User Pool sub
            final newPath = await generateS3Path(syncId, fileName);

            // Create migration mapping
            final mapping = FileMigrationMapping.create(
              legacyPath: legacyPath,
              newPath: newPath,
              userSub: userSub,
              syncId: syncId,
              fileName: fileName,
            );

            inventory.add(mapping);
            _logInfo('📋 Added to inventory: $legacyPath -> $newPath');
          } else {
            _logWarning('⚠️ Could not parse legacy path: $legacyPath');
          }
        } catch (e) {
          _logError('❌ Error processing legacy file $legacyPath: $e');
          // Continue with other files even if one fails
        }
      }

      _logInfo(
          '📊 Legacy file inventory complete: ${inventory.length} files ready for migration');
      return inventory;
    } catch (e) {
      _logError('❌ Failed to create legacy file inventory: $e');
      rethrow;
    }
  }

  /// Check if a specific sync ID has legacy files
  /// Useful for targeted migration of specific document sets
  ///
  /// [syncId] - The sync identifier to check for legacy files
  ///
  /// Returns true if legacy files exist for the sync ID
  Future<bool> hasLegacyFilesForSyncId(String syncId) async {
    _logInfo('🔍 Checking for legacy files with sync ID: $syncId');

    try {
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      final legacyFiles = await findLegacyFiles();

      // Check if any legacy files contain the specified sync ID
      for (final legacyPath in legacyFiles) {
        final extractedSyncId = _extractSyncIdFromLegacyPath(legacyPath);
        if (extractedSyncId == syncId) {
          _logInfo('✅ Found legacy files for sync ID: $syncId');
          return true;
        }
      }

      _logInfo('📭 No legacy files found for sync ID: $syncId');
      return false;
    } catch (e) {
      _logError('❌ Error checking legacy files for sync ID $syncId: $e');
      rethrow;
    }
  }

  /// Get legacy files for a specific sync ID
  /// Returns only the legacy files that match the specified sync ID
  ///
  /// [syncId] - The sync identifier to filter by
  ///
  /// Returns list of legacy file paths for the sync ID
  Future<List<String>> getLegacyFilesForSyncId(String syncId) async {
    _logInfo('🔍 Getting legacy files for sync ID: $syncId');

    try {
      if (syncId.isEmpty) {
        throw FilePathGenerationException('Sync ID cannot be empty');
      }

      final allLegacyFiles = await findLegacyFiles();
      final syncIdFiles = <String>[];

      for (final legacyPath in allLegacyFiles) {
        final extractedSyncId = _extractSyncIdFromLegacyPath(legacyPath);
        if (extractedSyncId == syncId) {
          syncIdFiles.add(legacyPath);
        }
      }

      _logInfo(
          '📋 Found ${syncIdFiles.length} legacy files for sync ID: $syncId');
      return syncIdFiles;
    } catch (e) {
      _logError('❌ Error getting legacy files for sync ID $syncId: $e');
      rethrow;
    }
  }

  /// Validate that a legacy file exists and is accessible
  /// Useful for verifying files before migration
  ///
  /// [legacyPath] - The legacy S3 path to validate
  ///
  /// Returns true if the legacy file exists and is accessible
  Future<bool> validateLegacyFile(String legacyPath) async {
    _logInfo('🔍 Validating legacy file: $legacyPath');

    try {
      if (legacyPath.isEmpty) {
        return false;
      }

      // Check if the path follows legacy format
      if (!_isValidLegacyFilePath(legacyPath)) {
        _logWarning('⚠️ Invalid legacy path format: $legacyPath');
        return false;
      }

      // Try to get file properties to verify it exists
      final properties = await Amplify.Storage.getProperties(
        path: StoragePath.fromString(legacyPath),
      ).result;

      _logInfo(
          '✅ Legacy file validated: $legacyPath (size: ${properties.storageItem.size})');
      return true;
    } on StorageException catch (e) {
      if (e.message.contains('NoSuchKey') || e.message.contains('not found')) {
        _logInfo('📭 Legacy file not found: $legacyPath');
        return false;
      } else {
        _logError('❌ Storage error validating legacy file: ${e.message}');
        return false;
      }
    } catch (e) {
      _logError('❌ Error validating legacy file $legacyPath: $e');
      return false;
    }
  }

  /// Utility methods

  /// Clear the cached User Pool sub to force refresh on next access
  /// Useful for testing or when user authentication state changes
  void clearCache() {
    _logInfo('🧹 PersistentFileService: Clearing User Pool sub cache');
    _cachedUserPoolSub = null;
    _cacheTimestamp = null;
  }

  /// Force refresh of the User Pool sub cache
  /// Retrieves fresh User Pool sub from Cognito and updates cache
  /// Returns the refreshed User Pool sub
  /// Throws [UserPoolSubException] if user is not authenticated or sub cannot be retrieved
  Future<String> refreshUserPoolSub() async {
    _logInfo('🔄 PersistentFileService: Refreshing User Pool sub cache');

    // Clear existing cache
    clearCache();

    // Get fresh User Pool sub (this will update the cache)
    return await getUserPoolSub();
  }

  /// Validate that the current user is authenticated and has a valid User Pool sub
  /// Returns true if user is authenticated with valid User Pool sub, false otherwise
  Future<bool> isUserAuthenticated() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final userPoolSub = user.userId;

      // Check if User Pool sub exists and is valid format
      return userPoolSub.isNotEmpty &&
          UserPoolSubValidator.isValidFormat(userPoolSub);
    } on AuthException catch (e) {
      _logWarning(
          '⚠️ User authentication check failed (AuthException): ${e.message}');
      return false;
    } catch (e) {
      _logWarning('⚠️ User authentication check failed: $e');
      return false;
    }
  }

  /// Get service status for debugging and monitoring
  /// Returns a map with service status information
  Map<String, dynamic> getServiceStatus() {
    return {
      'hasCachedUserPoolSub': _cachedUserPoolSub != null,
      'cacheAge': _cacheTimestamp != null
          ? DateTime.now().difference(_cacheTimestamp!).inMinutes
          : null,
      'cacheValid': _cachedUserPoolSub != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheValidDuration,
      'cachedUserPoolSubPreview': _cachedUserPoolSub != null
          ? '${_cachedUserPoolSub!.substring(0, 8)}...'
          : null,
    };
  }

  /// Get current user information for debugging (safe for logging)
  /// Returns user information with sensitive data masked
  Future<Map<String, dynamic>> getUserInfo() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      final userPoolSub = user.userId;

      return {
        'isAuthenticated': true,
        'userPoolSubPreview': userPoolSub.isNotEmpty
            ? '${userPoolSub.substring(0, 8)}...'
            : 'empty',
        'userPoolSubValid': UserPoolSubValidator.isValidFormat(userPoolSub),
        'username': user.username.isNotEmpty
            ? '${user.username.substring(0, 3)}***'
            : 'empty',
      };
    } on AuthException catch (e) {
      return {
        'isAuthenticated': false,
        'error': 'AuthException: ${e.message}',
      };
    } catch (e) {
      return {
        'isAuthenticated': false,
        'error': e.toString(),
      };
    }
  }

  /// Dispose resources and clear cache
  /// Should be called when the service is no longer needed
  void dispose() {
    _logInfo('🧹 PersistentFileService: Disposing service');
    clearCache();
  }

  // Private validation methods

  /// Validate inputs for path generation
  /// Throws [FilePathGenerationException] if inputs are invalid
  void _validatePathInputs(String syncId, String fileName) {
    if (syncId.isEmpty) {
      throw FilePathGenerationException('Sync ID cannot be empty');
    }

    if (fileName.isEmpty) {
      throw FilePathGenerationException('File name cannot be empty');
    }

    // Check for path traversal attempts
    if (syncId.contains('..') ||
        syncId.contains('/') ||
        syncId.contains('\\')) {
      throw FilePathGenerationException(
          'Sync ID contains invalid characters: $syncId');
    }

    if (fileName.contains('..') ||
        fileName.contains('/') ||
        fileName.contains('\\')) {
      throw FilePathGenerationException(
          'File name contains invalid path characters: $fileName');
    }

    // Check for excessively long inputs
    if (syncId.length > 100) {
      throw FilePathGenerationException(
          'Sync ID is too long (max 100 characters): ${syncId.length}');
    }

    if (fileName.length > 255) {
      throw FilePathGenerationException(
          'File name is too long (max 255 characters): ${fileName.length}');
    }
  }

  /// Validate a generated S3 path
  /// Returns true if the path is valid for S3 private access
  bool _validateGeneratedPath(String s3Path) {
    // Check basic format
    if (!s3Path.startsWith('private/')) {
      return false;
    }

    // Check path structure
    final parts = s3Path.split('/');
    if (parts.length < 5) {
      return false; // Should be: private/{userSub}/documents/{syncId}/{fileName}
    }

    // Validate User Pool sub in path
    final userSubInPath = parts[1];
    if (!UserPoolSubValidator.isValidFormat(userSubInPath)) {
      return false;
    }

    // Check documents folder
    if (parts[2] != 'documents') {
      return false;
    }

    // Check sync ID is not empty
    if (parts[3].isEmpty) {
      return false;
    }

    // Check filename is not empty
    if (parts[4].isEmpty) {
      return false;
    }

    return true;
  }

  // Private legacy file helper methods

  /// Validate that a file path follows the legacy format and belongs to the user
  /// Legacy format: protected/{username}/documents/{syncId}/{filename}
  bool _isValidLegacyFile(String filePath, String username) {
    if (filePath.isEmpty || username.isEmpty) {
      return false;
    }

    // Check if it follows legacy path format
    if (!_isValidLegacyFilePath(filePath)) {
      return false;
    }

    // Extract username from path and verify it matches
    final parts = filePath.split('/');
    if (parts.length >= 2) {
      final pathUsername = parts[1];
      if (pathUsername != username) {
        _logWarning(
            '⚠️ Username mismatch in legacy path: expected $username, found $pathUsername');
        return false;
      }
    }

    // Check that it's actually a file (has a filename with extension)
    final fileName = parts.last;
    if (fileName.isEmpty || !fileName.contains('.')) {
      return false;
    }

    return true;
  }

  /// Validate that a path follows the legacy format structure
  /// Legacy format: protected/{username}/documents/{syncId}/{filename}
  bool _isValidLegacyFilePath(String filePath) {
    if (filePath.isEmpty) {
      return false;
    }

    final parts = filePath.split('/');

    // Must have at least 5 parts: protected/{username}/documents/{syncId}/{filename}
    if (parts.length < 5) {
      return false;
    }

    // Must start with 'protected'
    if (parts[0] != 'protected') {
      return false;
    }

    // Must have 'documents' as the third part
    if (parts[2] != 'documents') {
      return false;
    }

    // Username (parts[1]) should not be empty
    if (parts[1].isEmpty) {
      return false;
    }

    // Sync ID (parts[3]) should not be empty
    if (parts[3].isEmpty) {
      return false;
    }

    // Filename (parts[4]) should not be empty and should have an extension
    if (parts[4].isEmpty || !parts[4].contains('.')) {
      return false;
    }

    return true;
  }

  /// Extract sync ID from legacy path
  /// Legacy format: protected/{username}/documents/{syncId}/{filename}
  String? _extractSyncIdFromLegacyPath(String legacyPath) {
    if (!_isValidLegacyFilePath(legacyPath)) {
      return null;
    }

    final parts = legacyPath.split('/');
    if (parts.length >= 4) {
      return parts[3]; // Sync ID is the 4th part (index 3)
    }

    return null;
  }

  /// Extract filename from legacy path
  /// Legacy format: protected/{username}/documents/{syncId}/{filename}
  /// Handles both timestamped and non-timestamped filenames
  String? _extractFileNameFromLegacyPath(String legacyPath) {
    if (!_isValidLegacyFilePath(legacyPath)) {
      return null;
    }

    final parts = legacyPath.split('/');
    if (parts.length >= 5) {
      final fullFileName = parts[4]; // Filename is the 5th part (index 4)

      // Check if filename has timestamp prefix (format: timestamp-filename)
      if (fullFileName.contains('-') && fullFileName.indexOf('-') > 0) {
        final dashIndex = fullFileName.indexOf('-');
        final timestampPart = fullFileName.substring(0, dashIndex);

        // Check if the part before dash is a valid timestamp (all digits)
        if (RegExp(r'^\d+$').hasMatch(timestampPart)) {
          // Return filename without timestamp
          return fullFileName.substring(dashIndex + 1);
        }
      }

      // Return full filename if no timestamp prefix found
      return fullFileName;
    }

    return null;
  }

  /// Extract username from legacy path
  /// Legacy format: protected/{username}/documents/{syncId}/{filename}
  String? _extractUsernameFromLegacyPath(String legacyPath) {
    if (!_isValidLegacyFilePath(legacyPath)) {
      return null;
    }

    final parts = legacyPath.split('/');
    if (parts.length >= 2) {
      return parts[1]; // Username is the 2nd part (index 1)
    }

    return null;
  }

  // Private migration helper methods

  /// Migrate a single file from legacy path to new User Pool sub-based path
  /// Returns true if migration was successful
  Future<bool> _migrateSingleFile(FileMigrationMapping mapping) async {
    _logInfo('🔄 Migrating file: ${mapping.legacyPath} -> ${mapping.newPath}');

    try {
      // Check if the new file already exists
      final newFileExists = await _fileExists(mapping.newPath);
      if (newFileExists) {
        _logInfo('✅ File already migrated: ${mapping.newPath}');
        return true;
      }

      // Check if the legacy file exists
      final legacyFileExists = await _fileExists(mapping.legacyPath);
      if (!legacyFileExists) {
        _logWarning('⚠️ Legacy file not found: ${mapping.legacyPath}');
        return false;
      }

      // Copy the file from legacy path to new path
      final success = await _copyFile(mapping.legacyPath, mapping.newPath);
      if (!success) {
        _logError(
            '❌ Failed to copy file: ${mapping.legacyPath} -> ${mapping.newPath}');
        return false;
      }

      // Verify the migration was successful
      final verified = await verifyMigration(mapping);
      if (!verified) {
        _logError('❌ Migration verification failed: ${mapping.newPath}');
        // Try to clean up the failed migration
        await _deleteFileIfExists(mapping.newPath);
        return false;
      }

      _logInfo('✅ File migration successful: ${mapping.newPath}');
      return true;
    } catch (e) {
      _logError('❌ Error migrating file ${mapping.legacyPath}: $e');
      return false;
    }
  }

  /// Copy a file from source path to destination path using S3 operations
  /// Returns true if copy was successful
  Future<bool> _copyFile(String sourcePath, String destinationPath) async {
    _logInfo('📋 Copying file: $sourcePath -> $destinationPath');

    try {
      // Download the source file to a temporary location
      final tempDir = '/tmp/migration_${DateTime.now().millisecondsSinceEpoch}';
      final tempFileName = destinationPath.split('/').last;
      final tempFilePath = '$tempDir/$tempFileName';

      // Download from source
      final downloadResult = await Amplify.Storage.downloadFile(
        path: StoragePath.fromString(sourcePath),
        localFile: AWSFile.fromPath(tempFilePath),
      ).result;

      if (downloadResult.localFile.path == null) {
        _logError('❌ Failed to download source file: $sourcePath');
        return false;
      }

      // Upload to destination
      await Amplify.Storage.uploadFile(
        localFile: AWSFile.fromPath(tempFilePath),
        path: StoragePath.fromString(destinationPath),
      ).result;

      _logInfo('✅ File copied successfully: $destinationPath');

      // Clean up temporary file
      try {
        // Note: In a real implementation, you'd want to delete the temp file
        // For now, we'll just log that we should clean it up
        _logInfo('🧹 Should clean up temp file: $tempFilePath');
      } catch (e) {
        _logWarning('⚠️ Could not clean up temp file: $e');
      }

      return true;
    } on StorageException catch (e) {
      _logError('❌ Storage error during file copy: ${e.message}');
      return false;
    } catch (e) {
      _logError('❌ Error copying file: $e');
      return false;
    }
  }

  /// Check if a file exists at the given S3 path
  /// Returns true if the file exists
  Future<bool> _fileExists(String s3Path) async {
    try {
      await Amplify.Storage.getProperties(
        path: StoragePath.fromString(s3Path),
      ).result;
      return true;
    } on StorageException catch (e) {
      if (e.message.contains('NoSuchKey') || e.message.contains('not found')) {
        return false;
      } else {
        _logError('❌ Error checking file existence: ${e.message}');
        return false;
      }
    } catch (e) {
      _logError('❌ Error checking file existence: $e');
      return false;
    }
  }

  /// Delete a file if it exists (used for cleanup)
  /// Returns true if file was deleted or didn't exist
  Future<bool> _deleteFileIfExists(String s3Path) async {
    try {
      final exists = await _fileExists(s3Path);
      if (!exists) {
        return true; // File doesn't exist, nothing to delete
      }

      await Amplify.Storage.remove(
        path: StoragePath.fromString(s3Path),
      ).result;

      _logInfo('🗑️ Cleaned up file: $s3Path');
      return true;
    } on StorageException catch (e) {
      _logError('❌ Error deleting file: ${e.message}');
      return false;
    } catch (e) {
      _logError('❌ Error deleting file: $e');
      return false;
    }
  }

  /// Download a file from legacy path (fallback functionality)
  /// Returns the local path where the file was downloaded
  Future<String> _downloadLegacyFile(
      String legacyS3Key, String syncId, String fileName) async {
    _logInfo('📥 Downloading legacy file: $legacyS3Key');

    try {
      // Create local file path for download
      final localPath = '/tmp/downloads/$syncId/$fileName';

      // Download file from legacy S3 path
      final downloadResult = await Amplify.Storage.downloadFile(
        path: StoragePath.fromString(legacyS3Key),
        localFile: AWSFile.fromPath(localPath),
      ).result;

      _logInfo(
          '✅ Legacy file downloaded successfully to: ${downloadResult.localFile.path}');
      return downloadResult.localFile.path ?? localPath;
    } on StorageException catch (e) {
      _logError('❌ Storage error during legacy file download: ${e.message}');
      throw FilePathGenerationException(
          'Legacy file download failed: ${e.message}');
    } catch (e) {
      _logError('❌ Error downloading legacy file: $e');
      rethrow;
    }
  }

  /// Retry and Circuit Breaker Management

  /// Get current operation queue status
  /// Returns information about queued operations for offline scenarios
  Map<String, dynamic> getQueueStatus() {
    final status = FileOperationErrorHandler.retryManager.getQueueStatus();
    return {
      'queueSize': status.queueSize,
      'isProcessing': status.isProcessing,
      'oldestOperation': status.oldestOperation?.toIso8601String(),
    };
  }

  /// Get circuit breaker status for file operations
  /// Returns circuit breaker information for monitoring
  Map<String, dynamic> getCircuitBreakerStatus() {
    final retryManager = FileOperationErrorHandler.retryManager;

    final operations = ['uploadFile', 'downloadFile', 'deleteFile'];
    final statuses = <String, Map<String, dynamic>>{};

    for (final operation in operations) {
      final status = retryManager.getCircuitBreakerStatus(operation);
      if (status != null) {
        statuses[operation] = {
          'state': status.state.toString(),
          'failureCount': status.failureCount,
          'lastFailureTime': status.lastFailureTime?.toIso8601String(),
          'nextAttemptTime': status.nextAttemptTime?.toIso8601String(),
        };
      }
    }

    return statuses;
  }

  /// Clear all circuit breakers (for testing or manual reset)
  /// This will reset all failure counts and circuit breaker states
  void clearCircuitBreakers() {
    _logInfo('🔄 PersistentFileService: Clearing all circuit breakers');
    FileOperationErrorHandler.retryManager.clearCircuitBreakers();
  }

  /// Clear operation queue (for testing or manual reset)
  /// This will remove all queued operations
  void clearOperationQueue() {
    _logInfo('🧹 PersistentFileService: Clearing operation queue');
    FileOperationErrorHandler.retryManager.clearQueue();
  }

  /// Get comprehensive service health status
  /// Returns detailed information about service state, retry mechanisms, and queues
  Future<Map<String, dynamic>> getHealthStatus() async {
    final serviceStatus = getServiceStatus();
    final queueStatus = getQueueStatus();
    final circuitBreakerStatus = getCircuitBreakerStatus();

    return {
      'service': serviceStatus,
      'queue': queueStatus,
      'circuitBreakers': circuitBreakerStatus,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Data Integrity Validation Methods

  /// Validate a file path for data integrity
  /// Returns ValidationResult with details about any issues found
  ValidationResult validateFilePathIntegrity(FilePath filePath) {
    _logInfo('🔍 PersistentFileService: Validating file path integrity');
    return _dataValidator.validateFilePath(filePath);
  }

  /// Validate and correct a file path if possible
  /// Returns CorrectionResult with the corrected path or error details
  CorrectionResult validateAndCorrectFilePath(FilePath filePath) {
    _logInfo('🔧 PersistentFileService: Validating and correcting file path');
    return _dataValidator.validateAndCorrectFilePath(filePath);
  }

  /// Validate User Pool sub format and consistency
  /// Returns ValidationResult with details about any issues found
  ValidationResult validateUserPoolSubIntegrity(String userPoolSub) {
    _logInfo('🔍 PersistentFileService: Validating User Pool sub integrity');
    return _dataValidator.validateUserPoolSub(userPoolSub);
  }

  /// Validate migration mapping for consistency
  /// Returns ValidationResult with details about any issues found
  ValidationResult validateMigrationMappingIntegrity(
      FileMigrationMapping mapping) {
    _logInfo(
        '🔍 PersistentFileService: Validating migration mapping integrity');
    return _dataValidator.validateMigrationMapping(mapping);
  }

  /// Perform automatic cleanup of invalid file references
  /// Identifies and removes invalid file references from the system
  ///
  /// [fileReferences] - List of S3 keys to validate and clean up
  ///
  /// Returns CleanupResult with details about the cleanup operation
  Future<CleanupResult> performFileReferenceCleanup(
      List<String> fileReferences) async {
    _logInfo(
        '🧹 PersistentFileService: Performing automatic cleanup of ${fileReferences.length} file references');
    return await _dataValidator.performAutomaticCleanup(fileReferences);
  }

  /// Validate current user's authentication state and User Pool sub consistency
  /// Returns ValidationResult with authentication validation details
  Future<ValidationResult> validateUserAuthenticationIntegrity() async {
    _logInfo(
        '🔍 PersistentFileService: Validating user authentication integrity');
    return await _dataValidator.validateCurrentUserAuthentication();
  }

  /// Get data integrity status for all cached and active file references
  /// Returns comprehensive integrity report
  Future<Map<String, dynamic>> getDataIntegrityStatus() async {
    _logInfo('📊 PersistentFileService: Getting data integrity status');

    final results = <String, dynamic>{};

    // Validate cached User Pool sub if present
    if (_cachedUserPoolSub != null) {
      final userSubValidation =
          _dataValidator.validateUserPoolSub(_cachedUserPoolSub!);
      results['cachedUserPoolSub'] = {
        'isValid': userSubValidation.isValid,
        'issues': userSubValidation.issues.map((i) => i.toString()).toList(),
      };
    }

    // Validate current user authentication
    try {
      final authValidation =
          await _dataValidator.validateCurrentUserAuthentication();
      results['userAuthentication'] = {
        'isValid': authValidation.isValid,
        'issues': authValidation.issues.map((i) => i.toString()).toList(),
      };
    } catch (e) {
      results['userAuthentication'] = {
        'isValid': false,
        'error': e.toString(),
      };
    }

    results['timestamp'] = DateTime.now().toIso8601String();

    return results;
  }

  /// Security validation methods

  /// Get security audit log for monitoring and compliance
  /// Returns list of security events for the current session
  List<SecurityAuditEntry> getSecurityAuditLog() {
    _logInfo('📋 PersistentFileService: Getting security audit log');
    return _securityValidator.getAuditLog();
  }

  /// Get recent security events (last 24 hours)
  /// Returns list of recent security events for monitoring
  List<SecurityAuditEntry> getRecentSecurityEvents() {
    _logInfo('📋 PersistentFileService: Getting recent security events');
    return _securityValidator.getRecentSecurityEvents();
  }

  /// Get security statistics for monitoring dashboard
  /// Returns comprehensive security metrics
  SecurityStats getSecurityStats() {
    _logInfo('📊 PersistentFileService: Getting security statistics');
    return _securityValidator.getSecurityStats();
  }

  /// Clear security audit log (for testing or maintenance)
  /// This will remove all security audit entries
  void clearSecurityAuditLog() {
    _logInfo('🧹 PersistentFileService: Clearing security audit log');
    _securityValidator.clearAuditLog();
  }

  /// Validate file for upload with comprehensive security checks
  /// Returns true if file passes all security validations
  ///
  /// [filePath] - Local path to the file to validate
  ///
  /// Returns true if file is safe for upload
  Future<bool> validateFileForUpload(String filePath) async {
    _logInfo('🔐 PersistentFileService: Validating file for upload: $filePath');
    return await _securityValidator.validateFileForUpload(filePath);
  }

  /// Validate S3 path for security compliance
  /// Returns true if S3 path follows security best practices
  ///
  /// [s3Key] - S3 key to validate
  ///
  /// Returns true if S3 path is secure
  Future<bool> validateS3PathSecurity(String s3Key) async {
    _logInfo('🔐 PersistentFileService: Validating S3 path security: $s3Key');
    return await _securityValidator.validateS3Path(s3Key);
  }

  /// Validate file ownership for access control
  /// Returns true if current user owns the specified file
  ///
  /// [s3Key] - S3 key to check ownership for
  ///
  /// Returns true if user owns the file
  Future<bool> validateFileOwnership(String s3Key) async {
    _logInfo('🔐 PersistentFileService: Validating file ownership: $s3Key');
    return await _securityValidator.validateFileOwnership(s3Key);
  }

  /// Validate user authentication with comprehensive security checks
  /// Returns true if user authentication passes all security validations
  ///
  /// Returns true if user is properly authenticated
  Future<bool> validateUserAuthenticationSecurity() async {
    _logInfo(
        '🔐 PersistentFileService: Validating user authentication security');
    return await _securityValidator.validateUserAuthentication();
  }

  /// Validate secure connection for file operations
  /// Returns true if connection meets security requirements
  ///
  /// Returns true if connection is secure
  Future<bool> validateSecureConnection() async {
    _logInfo('🔐 PersistentFileService: Validating secure connection');
    return await _securityValidator.validateSecureConnection();
  }

  /// Validate credential security for User Pool authentication
  /// Returns true if credentials are properly secured
  ///
  /// Returns true if credentials are secure
  Future<bool> validateCredentialSecurity() async {
    _logInfo('🔐 PersistentFileService: Validating credential security');
    return await _securityValidator.validateCredentialSecurity();
  }

  /// Validate data encryption for file operations
  /// Returns true if data encryption is properly configured
  ///
  /// Returns true if encryption is valid
  Future<bool> validateDataEncryption() async {
    _logInfo('🔐 PersistentFileService: Validating data encryption');
    return await _securityValidator.validateDataEncryption();
  }

  /// Validate certificate configuration for secure connections
  /// Returns true if certificate validation is properly configured
  ///
  /// Returns true if certificate validation is configured
  Future<bool> validateCertificate() async {
    _logInfo('🔐 PersistentFileService: Validating certificate configuration');
    return await _securityValidator.validateCertificate();
  }

  /// Perform comprehensive security validation
  /// Returns true if all security checks pass
  ///
  /// Returns true if all security validations pass
  Future<bool> validateComprehensiveSecurity() async {
    _logInfo(
        '🔐 PersistentFileService: Performing comprehensive security validation');
    return await _securityValidator.validateComprehensiveSecurity();
  }

  /// Sanitize sensitive data from logs
  /// Returns sanitized string with sensitive information masked
  ///
  /// [data] - Data to sanitize
  ///
  /// Returns sanitized string
  String sanitizeSensitiveData(String data) {
    return _securityValidator.sanitizeSensitiveData(data);
  }

  /// Get comprehensive security health status
  /// Returns detailed security status for monitoring
  Future<Map<String, dynamic>> getSecurityHealthStatus() async {
    _logInfo('📊 PersistentFileService: Getting security health status');

    final stats = getSecurityStats();
    final recentEvents = getRecentSecurityEvents();
    final authValid = await validateUserAuthenticationSecurity();
    final connectionSecure = await validateSecureConnection();
    final credentialsSecure = await validateCredentialSecurity();
    final encryptionValid = await validateDataEncryption();
    final certificateValid = await validateCertificate();

    return {
      'authenticationValid': authValid,
      'connectionSecure': connectionSecure,
      'credentialsSecure': credentialsSecure,
      'encryptionValid': encryptionValid,
      'certificateValid': certificateValid,
      'overallSecurityStatus': authValid &&
          connectionSecure &&
          credentialsSecure &&
          encryptionValid &&
          certificateValid,
      'securityStats': {
        'totalAuditEntries': stats.totalAuditEntries,
        'recentEvents': stats.recentEvents,
        'authenticationFailures': stats.authenticationFailures,
        'accessViolations': stats.accessViolations,
        'securityThreats': stats.securityThreats,
        'lastEventTime': stats.lastEventTime?.toIso8601String(),
      },
      'recentSecurityEvents': recentEvents
          .map((e) => {
                'timestamp': e.timestamp.toIso8601String(),
                'type': e.type.name,
                'message': sanitizeSensitiveData(e.message),
              })
          .toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
