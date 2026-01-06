import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/FileAttachment.dart';
import '../models/sync_state.dart';
import 'database_service.dart';
import 'log_service.dart' as app_log;
import 'sync_identifier_service.dart';

/// Manages synchronization of FileAttachment records with DynamoDB
/// Handles CRUD operations for file attachments in the cloud
class FileAttachmentSyncManager {
  static final FileAttachmentSyncManager _instance =
      FileAttachmentSyncManager._internal();
  factory FileAttachmentSyncManager() => _instance;
  FileAttachmentSyncManager._internal();

  final DatabaseService _databaseService = DatabaseService.instance;
  final app_log.LogService _logService = app_log.LogService();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);

  /// Upload a FileAttachment to DynamoDB
  /// Creates a new FileAttachment record in remote storage
  Future<FileAttachment> uploadFileAttachment(FileAttachment attachment) async {
    final startTime = DateTime.now();

    try {
      _logInfo('📤 Starting standalone FileAttachment upload to DynamoDB');
      _logInfo('   📄 File: ${attachment.fileName}');
      _logInfo('   🔗 Sync ID: ${attachment.syncId}');
      _logInfo('   👤 User ID: ${attachment.userId}');

      // Validate authentication before operation
      _logInfo('🔐 Validating user authentication...');
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (!authSession.isSignedIn) {
        _logError('❌ Authentication validation failed: User not signed in');
        throw Exception('User not authenticated');
      }
      _logInfo('✅ Authentication validated successfully');

      // Validate attachment has required fields
      if (attachment.syncId.isEmpty) {
        _logError(
            '❌ Validation failed: FileAttachment missing sync identifier');
        throw ArgumentError(
            'FileAttachment must have a sync identifier for upload');
      }

      // Validate sync identifier format
      SyncIdentifierService.validateOrThrow(attachment.syncId,
          context: 'FileAttachment upload');
      _logInfo('✅ FileAttachment validation completed');

      // Create the FileAttachment with synced state
      final attachmentToUpload = attachment.copyWith(
        syncState: SyncState.synced.toJson(),
      );

      // Use Amplify API to create FileAttachment in DynamoDB via GraphQL
      _logInfo('🚀 Sending GraphQL mutation to DynamoDB...');
      const graphQLDocument = '''
        mutation CreateFileAttachment(\$input: CreateFileAttachmentInput!) {
          createFileAttachment(input: \$input) {
            syncId
            userId
            fileName
            label
            fileSize
            s3Key
            filePath
            addedAt
            contentType
            checksum
            syncState
          }
        }
      ''';

      final request = GraphQLRequest<FileAttachment>(
        document: graphQLDocument,
        variables: {
          'input': {
            'syncId': attachmentToUpload.syncId,
            'userId': attachmentToUpload.userId,
            'fileName': attachmentToUpload.fileName,
            'label': attachmentToUpload.label,
            'fileSize': attachmentToUpload.fileSize,
            's3Key': attachmentToUpload.s3Key,
            'filePath': attachmentToUpload.filePath,
            'addedAt': attachmentToUpload.addedAt.format(),
            'contentType': attachmentToUpload.contentType,
            'checksum': attachmentToUpload.checksum,
            'syncState': attachmentToUpload.syncState,
          }
        },
        decodePath: 'createFileAttachment',
        modelType: FileAttachment.classType,
        authorizationMode: APIAuthorizationType.userPools,
      );

      final response = await Amplify.API.mutate(request: request).response;

      final requestDuration = DateTime.now().difference(startTime);
      _logInfo('📨 GraphQL response received');
      _logInfo('   ⏱️ Request duration: ${requestDuration.inMilliseconds}ms');

      if (response.hasErrors) {
        _logError('❌ GraphQL mutation failed with errors:');
        for (int i = 0; i < response.errors.length; i++) {
          final error = response.errors[i];
          _logError('   ${i + 1}. ${error.message}');
        }
        _logError('   📄 File: ${attachment.fileName}');
        _logError('   🔗 Sync ID: ${attachment.syncId}');

        throw Exception(
            'FileAttachment upload failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        _logError('❌ GraphQL mutation succeeded but returned no data');
        _logError('   📄 File: ${attachment.fileName}');
        _logError('   🔗 Sync ID: ${attachment.syncId}');

        throw Exception(
            'FileAttachment upload failed: No data returned from server');
      }

      final totalDuration = DateTime.now().difference(startTime);
      _logInfo('🎉 Standalone FileAttachment upload successful!');
      _logInfo('   📄 File: ${attachment.fileName}');
      _logInfo('   🔗 Created sync ID: ${response.data?.syncId}');
      _logInfo('   👤 User ID: ${response.data?.userId}');
      _logInfo('   📊 Sync state: ${response.data?.syncState}');
      _logInfo('   ⏱️ Total duration: ${totalDuration.inMilliseconds}ms');

      return response.data!;
    } catch (e) {
      final totalDuration = DateTime.now().difference(startTime);
      _logError('❌ Standalone FileAttachment upload failed');
      _logError('   📄 File: ${attachment.fileName}');
      _logError('   🔗 Sync ID: ${attachment.syncId}');
      _logError('   ⏱️ Failed after: ${totalDuration.inMilliseconds}ms');
      _logError('   🚨 Error: $e');

      rethrow;
    }
  }

  /// Download a FileAttachment from DynamoDB by syncId
  Future<FileAttachment?> downloadFileAttachment(String syncId) async {
    try {
      // Validate sync identifier format
      SyncIdentifierService.validateOrThrow(syncId,
          context: 'FileAttachment download');

      // Validate authentication before operation
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (!authSession.isSignedIn) {
        throw Exception('User not authenticated');
      }

      _logInfo('📥 Downloading FileAttachment from DynamoDB: $syncId');

      // Use Amplify API to get FileAttachment from DynamoDB via GraphQL
      const graphQLDocument = '''
        query GetFileAttachment(\$syncId: String!) {
          getFileAttachment(syncId: \$syncId) {
            syncId
            userId
            fileName
            label
            fileSize
            s3Key
            filePath
            addedAt
            contentType
            checksum
            syncState
          }
        }
      ''';

      final request = GraphQLRequest<FileAttachment>(
        document: graphQLDocument,
        variables: {'syncId': syncId},
        decodePath: 'getFileAttachment',
        modelType: FileAttachment.classType,
        authorizationMode: APIAuthorizationType.userPools,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        _logError(
            '❌ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
        throw Exception(
            'FileAttachment download failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        _logWarning('⚠️ FileAttachment not found: $syncId');
        return null;
      }

      _logInfo('✅ FileAttachment downloaded successfully: $syncId');
      return response.data!;
    } catch (e) {
      _logError('❌ Error downloading FileAttachment: $e');
      rethrow;
    }
  }

  /// Delete a FileAttachment from DynamoDB
  Future<void> deleteFileAttachment(String syncId) async {
    try {
      // Validate sync identifier format
      SyncIdentifierService.validateOrThrow(syncId,
          context: 'FileAttachment deletion');

      // Validate authentication before operation
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (!authSession.isSignedIn) {
        throw Exception('User not authenticated');
      }

      _logInfo('🗑️ Deleting FileAttachment from DynamoDB: $syncId');

      // Use Amplify API to delete FileAttachment from DynamoDB via GraphQL
      const graphQLDocument = '''
        mutation DeleteFileAttachment(\$input: DeleteFileAttachmentInput!) {
          deleteFileAttachment(input: \$input) {
            syncId
          }
        }
      ''';

      final request = GraphQLRequest<FileAttachment>(
        document: graphQLDocument,
        variables: {
          'input': {
            'syncId': syncId,
          }
        },
        decodePath: 'deleteFileAttachment',
        modelType: FileAttachment.classType,
        authorizationMode: APIAuthorizationType.userPools,
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        _logError(
            '❌ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
        throw Exception(
            'FileAttachment deletion failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      _logInfo('✅ FileAttachment deleted successfully from DynamoDB: $syncId');
    } catch (e) {
      _logError('❌ Error deleting FileAttachment: $e');
      rethrow;
    }
  }

  /// Sync all local FileAttachments for a document to DynamoDB
  Future<void> syncFileAttachmentsForDocument(String documentSyncId) async {
    final startTime = DateTime.now();
    int successCount = 0;
    int failureCount = 0;
    int skippedCount = 0;

    try {
      _logInfo('🔄 Starting FileAttachment sync for document: $documentSyncId');
      _logInfo('⏰ Sync started at: ${startTime.toIso8601String()}');

      // Get all local FileAttachments for the document by documentSyncId
      final localAttachments = await _databaseService
          .getFileAttachmentsByDocumentSyncId(documentSyncId);

      if (localAttachments.isEmpty) {
        _logInfo('📋 No FileAttachments found for document: $documentSyncId');
        _logInfo('✅ FileAttachment sync completed - no attachments to sync');
        return;
      }

      _logInfo(
          '📋 Found ${localAttachments.length} local FileAttachments to sync');
      _logInfo('📄 FileAttachment details:');
      for (int i = 0; i < localAttachments.length; i++) {
        final attachment = localAttachments[i];
        _logInfo(
            '   ${i + 1}. ${attachment.fileName} (${attachment.syncId}) - State: ${attachment.syncState}');
      }

      // Upload each FileAttachment to DynamoDB
      for (final attachment in localAttachments) {
        final attachmentStartTime = DateTime.now();

        try {
          // Check if attachment is already synced
          if (attachment.syncState == SyncState.synced.toJson()) {
            _logInfo(
                '⏭️ FileAttachment already synced, skipping: ${attachment.fileName}');
            _logInfo('   📊 Sync ID: ${attachment.syncId}');
            _logInfo('   📁 File size: ${attachment.fileSize} bytes');
            skippedCount++;
            continue;
          }

          _logInfo(
              '🚀 Starting sync for FileAttachment: ${attachment.fileName}');
          _logInfo('   📊 Sync ID: ${attachment.syncId}');
          _logInfo('   📁 File size: ${attachment.fileSize} bytes');
          _logInfo('   🏷️ Label: ${attachment.label ?? 'No label'}');
          _logInfo(
              '   🗂️ Content type: ${attachment.contentType ?? 'Unknown'}');

          // Upload to DynamoDB with document relationship
          final uploadedAttachment =
              await _uploadFileAttachmentWithDocumentLink(
                  attachment, documentSyncId);

          final attachmentDuration =
              DateTime.now().difference(attachmentStartTime);
          _logInfo('✅ FileAttachment sync successful: ${attachment.fileName}');
          _logInfo(
              '   ⏱️ Upload duration: ${attachmentDuration.inMilliseconds}ms');
          _logInfo('   🔗 DynamoDB sync ID: ${uploadedAttachment.syncId}');
          _logInfo('   📄 Linked to document: $documentSyncId');
          successCount++;
        } catch (e) {
          final attachmentDuration =
              DateTime.now().difference(attachmentStartTime);
          _logError('❌ Failed to sync FileAttachment: ${attachment.fileName}');
          _logError('   📊 Sync ID: ${attachment.syncId}');
          _logError(
              '   ⏱️ Failed after: ${attachmentDuration.inMilliseconds}ms');
          _logError('   🚨 Error details: $e');
          _logError('   📄 Document sync ID: $documentSyncId');
          failureCount++;
          // Continue with other attachments even if one fails
        }
      }

      final totalDuration = DateTime.now().difference(startTime);
      _logInfo(
          '🎉 FileAttachment sync completed for document: $documentSyncId');
      _logInfo('📊 Sync Summary:');
      _logInfo('   ✅ Successful: $successCount');
      _logInfo('   ❌ Failed: $failureCount');
      _logInfo('   ⏭️ Skipped (already synced): $skippedCount');
      _logInfo('   📋 Total processed: ${localAttachments.length}');
      _logInfo('   ⏱️ Total duration: ${totalDuration.inMilliseconds}ms');
      _logInfo(
          '   📈 Success rate: ${successCount > 0 ? ((successCount / (successCount + failureCount)) * 100).toStringAsFixed(1) : '0.0'}%');

      if (failureCount > 0) {
        _logWarning(
            '⚠️ Some FileAttachments failed to sync. Check error logs above for details.');
      }
    } catch (e) {
      final totalDuration = DateTime.now().difference(startTime);
      _logError(
          '❌ Critical error syncing FileAttachments for document $documentSyncId');
      _logError('   ⏱️ Failed after: ${totalDuration.inMilliseconds}ms');
      _logError(
          '   📊 Processed before failure: Success=$successCount, Failed=$failureCount, Skipped=$skippedCount');
      _logError('   🚨 Error details: $e');
      rethrow;
    }
  }

  /// Fetch all FileAttachments for a document from DynamoDB
  Future<List<FileAttachment>> fetchFileAttachmentsForDocument(
      String documentSyncId) async {
    try {
      // Validate authentication before operation
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (!authSession.isSignedIn) {
        throw Exception('User not authenticated');
      }

      _logInfo('📥 Fetching FileAttachments for document: $documentSyncId');

      // Query DynamoDB for FileAttachments belonging to the document
      const graphQLDocument = '''
        query ListFileAttachments(\$documentSyncId: String!) {
          listFileAttachments(filter: {documentSyncId: {eq: \$documentSyncId}}) {
            items {
              syncId
              userId
              fileName
              label
              fileSize
              s3Key
              filePath
              addedAt
              contentType
              checksum
              syncState
            }
          }
        }
      ''';

      final request = GraphQLRequest<PaginatedResult<FileAttachment>>(
        document: graphQLDocument,
        variables: {'documentSyncId': documentSyncId},
        decodePath: 'listFileAttachments',
        modelType: const PaginatedModelType(FileAttachment.classType),
        authorizationMode: APIAuthorizationType.userPools,
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        _logError(
            '❌ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
        throw Exception(
            'FileAttachment fetch failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      final attachments = response.data?.items
              .where((attachment) => attachment != null)
              .cast<FileAttachment>()
              .toList() ??
          [];

      _logInfo(
          '📋 Fetched ${attachments.length} FileAttachments for document: $documentSyncId');
      return attachments;
    } catch (e) {
      _logError(
          '❌ Error fetching FileAttachments for document $documentSyncId: $e');
      rethrow;
    }
  }

  /// Upload a FileAttachment with document relationship to DynamoDB
  Future<FileAttachment> _uploadFileAttachmentWithDocumentLink(
      FileAttachment attachment, String documentSyncId) async {
    final startTime = DateTime.now();

    try {
      _logInfo('📤 Starting FileAttachment DynamoDB upload');
      _logInfo('   📄 File: ${attachment.fileName}');
      _logInfo('   🔗 FileAttachment syncId: ${attachment.syncId}');
      _logInfo('   📄 Document syncId: $documentSyncId');
      _logInfo('   👤 User ID: ${attachment.userId}');
      _logInfo('   📁 File size: ${attachment.fileSize} bytes');
      _logInfo('   🏷️ Label: ${attachment.label ?? 'No label'}');
      _logInfo('   🗂️ Content type: ${attachment.contentType ?? 'Unknown'}');
      _logInfo('   🔑 S3 key: ${attachment.s3Key}');

      // Validate authentication before operation
      _logInfo('🔐 Validating user authentication...');
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (!authSession.isSignedIn) {
        _logError('❌ Authentication validation failed: User not signed in');
        throw Exception('User not authenticated');
      }
      _logInfo('✅ Authentication validated successfully');

      // Validate attachment has required fields
      _logInfo('🔍 Validating FileAttachment fields...');
      if (attachment.syncId.isEmpty) {
        _logError(
            '❌ Validation failed: FileAttachment missing sync identifier');
        throw ArgumentError(
            'FileAttachment must have a sync identifier for upload');
      }

      // Validate sync identifier format
      _logInfo('🔍 Validating sync identifier format...');
      SyncIdentifierService.validateOrThrow(attachment.syncId,
          context: 'FileAttachment upload');
      _logInfo('✅ Sync identifier format validated');

      // Create the FileAttachment with synced state
      final attachmentToUpload = attachment.copyWith(
        syncState: SyncState.synced.toJson(),
      );
      _logInfo('📝 Prepared FileAttachment for upload with synced state');

      // Use Amplify API to create FileAttachment in DynamoDB via GraphQL
      _logInfo('🚀 Sending GraphQL mutation to DynamoDB...');
      const graphQLDocument = '''
        mutation CreateFileAttachment(\$input: CreateFileAttachmentInput!) {
          createFileAttachment(input: \$input) {
            syncId
            documentSyncId
            userId
            fileName
            label
            fileSize
            s3Key
            filePath
            addedAt
            contentType
            checksum
            syncState
          }
        }
      ''';

      final request = GraphQLRequest<FileAttachment>(
        document: graphQLDocument,
        variables: {
          'input': {
            'syncId': attachmentToUpload.syncId,
            'documentSyncId': documentSyncId, // Link to the document
            'userId': attachmentToUpload.userId,
            'fileName': attachmentToUpload.fileName,
            'label': attachmentToUpload.label,
            'fileSize': attachmentToUpload.fileSize,
            's3Key': attachmentToUpload.s3Key,
            'filePath': attachmentToUpload.filePath,
            'addedAt': attachmentToUpload.addedAt.format(),
            'contentType': attachmentToUpload.contentType,
            'checksum': attachmentToUpload.checksum,
            'syncState': attachmentToUpload.syncState,
          }
        },
        decodePath: 'createFileAttachment',
        modelType: FileAttachment.classType,
        authorizationMode: APIAuthorizationType.userPools,
      );

      _logInfo('📡 GraphQL request prepared, executing mutation...');
      final response = await Amplify.API.mutate(request: request).response;

      final requestDuration = DateTime.now().difference(startTime);
      _logInfo('📨 GraphQL response received');
      _logInfo('   ⏱️ Request duration: ${requestDuration.inMilliseconds}ms');
      _logInfo('   ❓ Has errors: ${response.hasErrors}');

      if (response.hasErrors) {
        _logError('❌ GraphQL mutation failed with errors:');
        for (int i = 0; i < response.errors.length; i++) {
          final error = response.errors[i];
          _logError('   ${i + 1}. ${error.message}');
          if (error.locations != null) {
            _logError('      📍 Location: ${error.locations}');
          }
          if (error.path != null) {
            _logError('      🛤️ Path: ${error.path}');
          }
        }
        _logError('   📄 File: ${attachment.fileName}');
        _logError('   🔗 Sync ID: ${attachment.syncId}');
        _logError('   📄 Document sync ID: $documentSyncId');

        throw Exception(
            'FileAttachment upload failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        _logError('❌ GraphQL mutation succeeded but returned no data');
        _logError('   📄 File: ${attachment.fileName}');
        _logError('   🔗 Sync ID: ${attachment.syncId}');
        _logError('   📄 Document sync ID: $documentSyncId');
        _logError(
            '   ⏱️ Request duration: ${requestDuration.inMilliseconds}ms');

        throw Exception(
            'FileAttachment upload failed: No data returned from server');
      }

      final totalDuration = DateTime.now().difference(startTime);
      _logInfo('🎉 FileAttachment DynamoDB record created successfully!');
      _logInfo('   📄 File: ${attachment.fileName}');
      _logInfo('   🔗 Created sync ID: ${response.data?.syncId}');
      _logInfo('   📄 Linked to document: $documentSyncId');
      _logInfo('   👤 User ID: ${response.data?.userId}');
      _logInfo('   📁 File size: ${response.data?.fileSize} bytes');
      _logInfo('   🏷️ Label: ${response.data?.label ?? 'No label'}');
      _logInfo('   🔑 S3 key: ${response.data?.s3Key}');
      _logInfo('   📊 Sync state: ${response.data?.syncState}');
      _logInfo(
          '   ⏱️ Total upload duration: ${totalDuration.inMilliseconds}ms');
      _logInfo('   📅 Added at: ${response.data!.addedAt.format()}');

      return response.data!;
    } catch (e) {
      final totalDuration = DateTime.now().difference(startTime);
      _logError('❌ FileAttachment DynamoDB upload failed');
      _logError('   📄 File: ${attachment.fileName}');
      _logError('   🔗 Sync ID: ${attachment.syncId}');
      _logError('   📄 Document sync ID: $documentSyncId');
      _logError('   👤 User ID: ${attachment.userId}');
      _logError('   📁 File size: ${attachment.fileSize} bytes');
      _logError('   🔑 S3 key: ${attachment.s3Key}');
      _logError('   ⏱️ Failed after: ${totalDuration.inMilliseconds}ms');
      _logError('   🚨 Error type: ${e.runtimeType}');
      _logError('   🚨 Error details: $e');

      rethrow;
    }
  }
}
