import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'log_service.dart' as log_svc;

/// Custom exception for file attachment sync operations
class FileAttachmentSyncException implements Exception {
  final String message;
  FileAttachmentSyncException(this.message);

  @override
  String toString() => 'FileAttachmentSyncException: $message';
}

/// Service for syncing file attachment metadata between local SQLite and remote DynamoDB
///
/// This service handles:
/// - Creating FileAttachment records in DynamoDB after S3 upload
/// - Updating FileAttachment records when metadata changes
/// - Deleting FileAttachment records (soft delete)
class FileAttachmentSyncService {
  static final FileAttachmentSyncService _instance =
      FileAttachmentSyncService._internal();
  factory FileAttachmentSyncService() => _instance;
  FileAttachmentSyncService._internal();

  final _logService = log_svc.LogService();

  /// Create a FileAttachment record in DynamoDB
  Future<void> createRemoteFileAttachment({
    required String syncId,
    required String documentSyncId,
    required String userId,
    required String fileName,
    String? label,
    required int fileSize,
    required String s3Key,
    required String filePath,
    required DateTime addedAt,
    String? contentType,
    String? checksum,
    required String syncState,
  }) async {
    try {
      _logService.log(
        'Creating remote file attachment: $fileName',
        level: log_svc.LogLevel.info,
      );

      const mutation = '''
        mutation CreateFileAttachment(
          \$syncId: String!,
          \$documentSyncId: String!,
          \$userId: String!,
          \$fileName: String!,
          \$label: String,
          \$fileSize: Int!,
          \$s3Key: String!,
          \$filePath: String!,
          \$addedAt: AWSDateTime!,
          \$contentType: String,
          \$checksum: String,
          \$syncState: String!
        ) {
          createFileAttachment(input: {
            syncId: \$syncId,
            documentSyncId: \$documentSyncId,
            userId: \$userId,
            fileName: \$fileName,
            label: \$label,
            fileSize: \$fileSize,
            s3Key: \$s3Key,
            filePath: \$filePath,
            addedAt: \$addedAt,
            contentType: \$contentType,
            checksum: \$checksum,
            syncState: \$syncState
          }) {
            syncId
            documentSyncId
            fileName
            s3Key
            addedAt
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'syncId': syncId,
          'documentSyncId': documentSyncId,
          'userId': userId,
          'fileName': fileName,
          'label': label,
          'fileSize': fileSize,
          's3Key': s3Key,
          'filePath': filePath,
          'addedAt': addedAt.toUtc().toIso8601String(),
          'contentType': contentType,
          'checksum': checksum,
          'syncState': syncState,
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw FileAttachmentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      _logService.log(
        'Created remote file attachment: $fileName',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to create remote file attachment: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Update a FileAttachment record in DynamoDB
  Future<void> updateRemoteFileAttachment({
    required String syncId,
    required String documentSyncId,
    String? label,
    String? syncState,
  }) async {
    try {
      _logService.log(
        'Updating remote file attachment: $syncId',
        level: log_svc.LogLevel.info,
      );

      const mutation = '''
        mutation UpdateFileAttachment(
          \$syncId: String!,
          \$documentSyncId: String!,
          \$label: String,
          \$syncState: String
        ) {
          updateFileAttachment(input: {
            syncId: \$syncId,
            documentSyncId: \$documentSyncId,
            label: \$label,
            syncState: \$syncState
          }) {
            syncId
            label
            syncState
          }
        }
      ''';

      final variables = <String, dynamic>{
        'syncId': syncId,
        'documentSyncId': documentSyncId,
      };

      if (label != null) variables['label'] = label;
      if (syncState != null) variables['syncState'] = syncState;

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: variables,
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw FileAttachmentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      _logService.log(
        'Updated remote file attachment: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to update remote file attachment: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Delete a FileAttachment record from DynamoDB
  Future<void> deleteRemoteFileAttachment({
    required String syncId,
  }) async {
    try {
      _logService.log(
        'Deleting remote file attachment: $syncId',
        level: log_svc.LogLevel.info,
      );

      const mutation = '''
        mutation DeleteFileAttachment(
          \$syncId: String!
        ) {
          deleteFileAttachment(input: {
            syncId: \$syncId
          }) {
            syncId
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'syncId': syncId,
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw FileAttachmentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      _logService.log(
        'Deleted remote file attachment: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to delete remote file attachment: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Fetch all FileAttachments for a document from DynamoDB
  Future<List<Map<String, dynamic>>> fetchRemoteFileAttachments(
      String documentSyncId) async {
    try {
      _logService.log(
        'Fetching remote file attachments for document: $documentSyncId',
        level: log_svc.LogLevel.info,
      );

      const query = '''
        query ListFileAttachments(\$documentSyncId: String!) {
          listFileAttachments(filter: {documentSyncId: {eq: \$documentSyncId}}) {
            items {
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
        }
      ''';

      final request = GraphQLRequest<String>(
        document: query,
        variables: {'documentSyncId': documentSyncId},
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        throw FileAttachmentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      if (response.data == null) {
        return [];
      }

      final jsonData = jsonDecode(response.data!);
      final items = jsonData['listFileAttachments']['items'] as List;

      _logService.log(
        'Found ${items.length} remote file attachments',
        level: log_svc.LogLevel.info,
      );

      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      _logService.log(
        'Failed to fetch remote file attachments: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }
}
