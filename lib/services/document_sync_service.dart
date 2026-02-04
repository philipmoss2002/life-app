import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/new_document.dart' as local;
import '../models/sync_state.dart' as local_sync;
import '../repositories/document_repository.dart';
import 'authentication_service.dart';
import 'log_service.dart' as log_svc;

/// Custom exception for document sync operations
class DocumentSyncException implements Exception {
  final String message;
  DocumentSyncException(this.message);

  @override
  String toString() => 'DocumentSyncException: $message';
}

/// Service for syncing document metadata between local SQLite and remote DocumentDB
///
/// This service handles:
/// - Pushing local document changes to DocumentDB (GraphQL mutations)
/// - Pulling remote document changes from DocumentDB (GraphQL queries)
/// - Conflict resolution (last-write-wins strategy)
/// - Tombstone tracking for deletions
class DocumentSyncService {
  static final DocumentSyncService _instance = DocumentSyncService._internal();
  factory DocumentSyncService() => _instance;
  DocumentSyncService._internal();

  final _documentRepository = DocumentRepository();
  final _authService = AuthenticationService();
  final _logService = log_svc.LogService();

  /// Push a local document to DocumentDB
  Future<void> pushDocumentToRemote(local.Document localDoc) async {
    try {
      _logService.log(
        'Pushing document to remote: ${localDoc.syncId}',
        level: log_svc.LogLevel.info,
      );

      // Get current user ID (using Cognito User Pool sub claim)
      final userId = await _authService.getUserId();

      // Check if document exists remotely
      final existingDoc = await _fetchRemoteDocument(localDoc.syncId);

      if (existingDoc != null) {
        // Update existing document
        await _updateRemoteDocument(localDoc, userId);
      } else {
        // Create new document
        await _createRemoteDocument(localDoc, userId);
      }

      _logService.log(
        'Document pushed successfully: ${localDoc.syncId}',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to push document ${localDoc.syncId}: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Create a new document in DocumentDB
  Future<void> _createRemoteDocument(
    local.Document localDoc,
    String userId,
  ) async {
    try {
      const mutation = '''
        mutation CreateDocument(
          \$syncId: String!,
          \$userId: String!,
          \$title: String!,
          \$category: String!,
          \$date: AWSDateTime,
          \$notes: String,
          \$createdAt: AWSDateTime!,
          \$updatedAt: AWSDateTime!,
          \$syncState: String!,
          \$deleted: Boolean
        ) {
          createDocument(input: {
            syncId: \$syncId,
            userId: \$userId,
            title: \$title,
            category: \$category,
            date: \$date,
            notes: \$notes,
            createdAt: \$createdAt,
            updatedAt: \$updatedAt,
            syncState: \$syncState,
            deleted: \$deleted
          }) {
            syncId
            userId
            title
            category
            createdAt
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'syncId': localDoc.syncId,
          'userId': userId,
          'title': localDoc.title,
          'category': _mapCategoryToRemote(localDoc.category),
          'date': localDoc.date?.toUtc().toIso8601String(),
          'notes': localDoc.notes,
          'createdAt': localDoc.createdAt.toUtc().toIso8601String(),
          'updatedAt': localDoc.updatedAt.toUtc().toIso8601String(),
          'syncState': localDoc.syncState.name,
          'deleted': false,
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw DocumentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      _logService.log(
        'Created remote document: ${localDoc.syncId}',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to create remote document: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Update an existing document in DocumentDB
  Future<void> _updateRemoteDocument(
    local.Document localDoc,
    String userId,
  ) async {
    try {
      const mutation = '''
        mutation UpdateDocument(
          \$syncId: String!,
          \$title: String!,
          \$category: String!,
          \$date: AWSDateTime,
          \$notes: String,
          \$updatedAt: AWSDateTime!,
          \$syncState: String!,
          \$deleted: Boolean
        ) {
          updateDocument(input: {
            syncId: \$syncId,
            title: \$title,
            category: \$category,
            date: \$date,
            notes: \$notes,
            updatedAt: \$updatedAt,
            syncState: \$syncState,
            deleted: \$deleted
          }) {
            syncId
            userId
            title
            category
            updatedAt
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'syncId': localDoc.syncId,
          'title': localDoc.title,
          'category': _mapCategoryToRemote(localDoc.category),
          'date': localDoc.date?.toUtc().toIso8601String(),
          'notes': localDoc.notes,
          'updatedAt': localDoc.updatedAt.toUtc().toIso8601String(),
          'syncState': localDoc.syncState.name,
          'deleted': false,
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw DocumentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      _logService.log(
        'Updated remote document: ${localDoc.syncId}',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to update remote document: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Fetch a document from DocumentDB
  Future<Map<String, dynamic>?> _fetchRemoteDocument(String syncId) async {
    try {
      const query = '''
        query GetDocument(\$syncId: String!) {
          getDocument(syncId: \$syncId) {
            syncId
            userId
            title
            category
            date
            notes
            createdAt
            updatedAt
            syncState
            deleted
            deletedAt
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: query,
        variables: {'syncId': syncId},
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        _logService.log(
          'GraphQL errors fetching document: ${response.errors.map((e) => e.message).join(", ")}',
          level: log_svc.LogLevel.warning,
        );
        return null;
      }

      if (response.data == null) {
        return null;
      }

      // Parse JSON response
      final jsonData = jsonDecode(response.data!);
      final docData = jsonData['getDocument'];

      return docData as Map<String, dynamic>?;
    } catch (e) {
      _logService.log(
        'Failed to fetch remote document $syncId: $e',
        level: log_svc.LogLevel.error,
      );
      return null;
    }
  }

  /// Pull all remote documents and merge with local
  Future<void> pullRemoteDocuments() async {
    try {
      _logService.log(
        'Pulling remote documents',
        level: log_svc.LogLevel.info,
      );

      // Get current user ID (using Cognito User Pool sub claim)
      final userId = await _authService.getUserId();

      // Fetch all documents for this user
      final remoteDocs = await _fetchAllRemoteDocuments(userId);

      _logService.log(
        'Found ${remoteDocs.length} remote documents',
        level: log_svc.LogLevel.info,
      );

      int createdCount = 0;
      int updatedCount = 0;
      int skippedCount = 0;

      for (final remoteDoc in remoteDocs) {
        try {
          // Skip deleted documents
          if (remoteDoc['deleted'] == true) {
            continue;
          }

          final syncId = remoteDoc['syncId'] as String;
          final localDoc = await _documentRepository.getDocument(syncId);

          if (localDoc == null) {
            // New remote document - create locally
            await _createLocalDocumentFromMap(remoteDoc);
            createdCount++;
          } else {
            // Check which is newer
            final remoteUpdated =
                DateTime.parse(remoteDoc['updatedAt'] as String);
            final localUpdated = localDoc.updatedAt;

            if (remoteUpdated.isAfter(localUpdated)) {
              // Remote is newer - update local
              await _updateLocalDocumentFromMap(remoteDoc, localDoc);
              updatedCount++;
            } else {
              // Local is newer or same - skip
              skippedCount++;
            }
          }
        } catch (e) {
          _logService.log(
            'Failed to process remote document ${remoteDoc['syncId']}: $e',
            level: log_svc.LogLevel.error,
          );
        }
      }

      _logService.log(
        'Pull complete: $createdCount created, $updatedCount updated, $skippedCount skipped',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to pull remote documents: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Fetch all documents for a user from DocumentDB
  Future<List<Map<String, dynamic>>> _fetchAllRemoteDocuments(
      String userId) async {
    try {
      const query = '''
        query ListDocuments(\$userId: String!) {
          listDocuments(filter: {userId: {eq: \$userId}}) {
            items {
              syncId
              userId
              title
              category
              date
              notes
              createdAt
              updatedAt
              syncState
              deleted
              deletedAt
              fileAttachments {
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
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: query,
        variables: {'userId': userId},
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        throw DocumentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      if (response.data == null) {
        return [];
      }

      // Parse JSON response
      final jsonData = jsonDecode(response.data!);
      final items = jsonData['listDocuments']['items'] as List;

      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      _logService.log(
        'Failed to fetch all remote documents: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Create a local document from remote data
  Future<void> _createLocalDocumentFromMap(
      Map<String, dynamic> remoteDoc) async {
    try {
      final localDoc = local.Document(
        syncId: remoteDoc['syncId'] as String,
        title: remoteDoc['title'] as String,
        category: _mapCategoryToLocal(remoteDoc['category'] as String),
        date: remoteDoc['date'] != null
            ? DateTime.parse(remoteDoc['date'] as String)
            : null,
        notes: remoteDoc['notes'] as String?,
        createdAt: DateTime.parse(remoteDoc['createdAt'] as String),
        updatedAt: DateTime.parse(remoteDoc['updatedAt'] as String),
        syncState: _mapSyncStateToLocal(remoteDoc['syncState'] as String?),
        files: [], // Files handled separately below
      );

      // Insert into local database using repository method
      await _documentRepository.insertRemoteDocument(localDoc);

      // Sync file attachments
      await _syncFileAttachmentsFromMap(remoteDoc);

      _logService.log(
        'Created local document from remote: ${remoteDoc['syncId']}',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to create local document: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Update a local document with remote data
  Future<void> _updateLocalDocumentFromMap(
    Map<String, dynamic> remoteDoc,
    local.Document localDoc,
  ) async {
    try {
      final updatedDoc = localDoc.copyWith(
        title: remoteDoc['title'] as String,
        category: _mapCategoryToLocal(remoteDoc['category'] as String),
        date: remoteDoc['date'] != null
            ? DateTime.parse(remoteDoc['date'] as String)
            : null,
        notes: remoteDoc['notes'] as String?,
        updatedAt: DateTime.parse(remoteDoc['updatedAt'] as String),
        syncState: _mapSyncStateToLocal(remoteDoc['syncState'] as String?),
      );

      await _documentRepository.updateDocument(updatedDoc);

      // Sync file attachments
      await _syncFileAttachmentsFromMap(remoteDoc);

      _logService.log(
        'Updated local document from remote: ${remoteDoc['syncId']}',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to update local document: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Delete a document from DocumentDB (soft delete with tombstone)
  Future<void> deleteRemoteDocument(String syncId) async {
    try {
      _logService.log(
        'Deleting remote document: $syncId',
        level: log_svc.LogLevel.info,
      );

      final userId = await _authService.getUserId();

      // Fetch the document first
      final remoteDoc = await _fetchRemoteDocument(syncId);
      if (remoteDoc == null) {
        _logService.log(
          'Remote document not found: $syncId',
          level: log_svc.LogLevel.warning,
        );
        return;
      }

      // Mark as deleted
      const mutation = '''
        mutation UpdateDocument(
          \$syncId: String!,
          \$title: String!,
          \$category: String!,
          \$date: AWSDateTime,
          \$notes: String,
          \$createdAt: AWSDateTime!,
          \$updatedAt: AWSDateTime!,
          \$syncState: String!,
          \$deleted: Boolean,
          \$deletedAt: AWSDateTime
        ) {
          updateDocument(input: {
            syncId: \$syncId,
            title: \$title,
            category: \$category,
            date: \$date,
            notes: \$notes,
            createdAt: \$createdAt,
            updatedAt: \$updatedAt,
            syncState: \$syncState,
            deleted: \$deleted,
            deletedAt: \$deletedAt
          }) {
            syncId
            deleted
            deletedAt
          }
        }
      ''';

      final now = DateTime.now().toUtc().toIso8601String();
      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'syncId': remoteDoc['syncId'],
          'title': remoteDoc['title'],
          'category': remoteDoc['category'],
          'date': remoteDoc['date'],
          'notes': remoteDoc['notes'],
          'createdAt': remoteDoc['createdAt'],
          'updatedAt': now,
          'syncState': remoteDoc['syncState'],
          'deleted': true,
          'deletedAt': now,
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw DocumentSyncException(
          'GraphQL errors: ${response.errors.map((e) => e.message).join(", ")}',
        );
      }

      // Create tombstone
      await _createTombstone(syncId, userId);

      _logService.log(
        'Deleted remote document: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to delete remote document: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Create a tombstone record for deleted document
  Future<void> _createTombstone(String syncId, String userId) async {
    try {
      const mutation = '''
        mutation CreateDocumentTombstone(
          \$syncId: String!,
          \$userId: String!,
          \$deletedAt: AWSDateTime!,
          \$deletedBy: String!,
          \$reason: String!
        ) {
          createDocumentTombstone(input: {
            syncId: \$syncId,
            userId: \$userId,
            deletedAt: \$deletedAt,
            deletedBy: \$deletedBy,
            reason: \$reason
          }) {
            syncId
            userId
            deletedAt
          }
        }
      ''';

      final request = GraphQLRequest<String>(
        document: mutation,
        variables: {
          'syncId': syncId,
          'userId': userId,
          'deletedAt': DateTime.now().toUtc().toIso8601String(),
          'deletedBy': userId,
          'reason': 'User deleted',
        },
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        _logService.log(
          'Failed to create tombstone: ${response.errors.map((e) => e.message).join(", ")}',
          level: log_svc.LogLevel.warning,
        );
      }
    } catch (e) {
      _logService.log(
        'Failed to create tombstone: $e',
        level: log_svc.LogLevel.warning,
      );
    }
  }

  /// Map local category to remote category string
  String _mapCategoryToRemote(local.DocumentCategory category) {
    switch (category) {
      case local.DocumentCategory.carInsurance:
        return 'CAR_INSURANCE';
      case local.DocumentCategory.homeInsurance:
        return 'HOME_INSURANCE';
      case local.DocumentCategory.holiday:
        return 'HOLIDAY';
      case local.DocumentCategory.expenses:
        return 'EXPENSES';
      case local.DocumentCategory.other:
        return 'OTHER';
    }
  }

  /// Map remote category string to local category
  local.DocumentCategory _mapCategoryToLocal(String category) {
    switch (category) {
      case 'CAR_INSURANCE':
        return local.DocumentCategory.carInsurance;
      case 'HOME_INSURANCE':
        return local.DocumentCategory.homeInsurance;
      case 'HOLIDAY':
        return local.DocumentCategory.holiday;
      case 'EXPENSES':
        return local.DocumentCategory.expenses;
      case 'OTHER':
      default:
        return local.DocumentCategory.other;
    }
  }

  /// Map remote sync state string to local sync state
  local_sync.SyncState _mapSyncStateToLocal(String? syncState) {
    if (syncState == null) return local_sync.SyncState.pendingUpload;

    switch (syncState.toLowerCase()) {
      case 'synced':
        return local_sync.SyncState.synced;
      case 'pendingupload':
        return local_sync.SyncState.pendingUpload;
      case 'pendingdownload':
        return local_sync.SyncState.pendingDownload;
      case 'uploading':
        return local_sync.SyncState.uploading;
      case 'downloading':
        return local_sync.SyncState.downloading;
      case 'error':
        return local_sync.SyncState.error;
      default:
        return local_sync.SyncState.pendingUpload;
    }
  }

  /// Sync file attachments from remote document data
  Future<void> _syncFileAttachmentsFromMap(
      Map<String, dynamic> remoteDoc) async {
    final syncId = remoteDoc['syncId'] as String;
    final fileAttachmentsData = remoteDoc['fileAttachments'];

    if (fileAttachmentsData == null) {
      _logService.log(
        'No fileAttachments field in remote document: $syncId',
        level: log_svc.LogLevel.debug,
      );
      return;
    }

    final items = fileAttachmentsData['items'] as List?;
    if (items == null || items.isEmpty) {
      _logService.log(
        'No file attachments to sync for document: $syncId',
        level: log_svc.LogLevel.debug,
      );
      return;
    }

    try {
      // Get existing file attachments
      final existingFiles =
          await _documentRepository.getFileAttachments(syncId);
      final existingFileNames = existingFiles.map((f) => f.fileName).toSet();

      _logService.log(
        'Syncing ${items.length} file attachments for document: $syncId',
        level: log_svc.LogLevel.info,
      );

      // Add or update file attachments from remote
      for (final remoteFile in items) {
        final fileName = remoteFile['fileName'] as String;
        final s3Key = remoteFile['s3Key'] as String;
        final fileSize = remoteFile['fileSize'] as int;
        final label = remoteFile['label'] as String?;
        // Note: filePath from remote is the S3 path, not a local path
        // We should NOT use it as localPath - file needs to be downloaded first

        if (existingFileNames.contains(fileName)) {
          // Update existing file attachment
          _logService.log(
            'Updating existing file attachment: $fileName',
            level: log_svc.LogLevel.debug,
          );

          await _documentRepository.updateFileS3Key(
            syncId: syncId,
            fileName: fileName,
            s3Key: s3Key,
          );

          if (label != null) {
            await _documentRepository.updateFileLabel(
              syncId: syncId,
              fileName: fileName,
              label: label,
            );
          }

          // Don't update localPath from remote - it's the S3 path, not local
        } else {
          // Add new file attachment
          _logService.log(
            'Adding new file attachment: $fileName',
            level: log_svc.LogLevel.debug,
          );

          await _documentRepository.addFileAttachment(
            syncId: syncId,
            fileName: fileName,
            label: label,
            s3Key: s3Key,
            fileSize: fileSize,
            localPath: null, // File not downloaded yet
          );
        }
      }

      // Remove file attachments that no longer exist remotely
      final remoteFileNames = items.map((f) => f['fileName'] as String).toSet();
      for (final existingFile in existingFiles) {
        if (!remoteFileNames.contains(existingFile.fileName)) {
          _logService.log(
            'Removing file attachment no longer in remote: ${existingFile.fileName}',
            level: log_svc.LogLevel.debug,
          );

          await _documentRepository.deleteFileAttachment(
            syncId: syncId,
            fileName: existingFile.fileName,
          );
        }
      }

      _logService.log(
        'File attachment sync completed for document: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Error syncing file attachments for document $syncId: $e',
        level: log_svc.LogLevel.error,
      );
      // Don't rethrow - document sync should succeed even if file sync fails
    }
  }
}
