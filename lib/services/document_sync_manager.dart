import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:uuid/uuid.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';
import 'retry_manager.dart';
import 'auth_token_manager.dart';
import 'version_conflict_manager.dart';
import 'error_state_manager.dart';
import 'document_validation_service.dart';
import 'performance_monitor.dart';
import 'log_service.dart' as app_log;
import 'sync_identifier_service.dart';
import 'file_attachment_sync_manager.dart';

/// Exception thrown when a version conflict is detected
class VersionConflictException implements Exception {
  final String message;
  final Document localDocument;
  final Document remoteDocument;

  VersionConflictException({
    required this.message,
    required this.localDocument,
    required this.remoteDocument,
  });

  @override
  String toString() => 'VersionConflictException: $message';
}

/// Manages synchronization of document metadata with DynamoDB
/// Handles CRUD operations, version tracking, and conflict detection
class DocumentSyncManager {
  static final DocumentSyncManager _instance = DocumentSyncManager._internal();
  factory DocumentSyncManager() => _instance;
  DocumentSyncManager._internal();

  final RetryManager _retryManager = RetryManager();
  final AuthTokenManager _authManager = AuthTokenManager();
  final VersionConflictManager _conflictManager = VersionConflictManager();
  final ErrorStateManager _errorManager = ErrorStateManager();
  final DocumentValidationService _validationService =
      DocumentValidationService();
  final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  final app_log.LogService _logService = app_log.LogService();
  final FileAttachmentSyncManager _fileAttachmentSyncManager =
      FileAttachmentSyncManager();

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);

  /// Handle duplicate sync ID errors by generating a new sync ID and retrying
  Future<Document> _handleDuplicateSyncIdError(
    Document document,
    String graphQLDocument,
    Exception originalError,
  ) async {
    _logWarning(
        'Handling duplicate sync ID error for document: ${document.syncId}');

    // Generate a new unique sync identifier
    final newSyncId = const Uuid().v4();

    // Create new document instance with new sync ID
    final retryDocument = Document(
      syncId: newSyncId,
      userId: document.userId,
      title: document.title,
      category: document.category,
      filePaths: document.filePaths,
      renewalDate: document.renewalDate,
      notes: document.notes,
      createdAt: document.createdAt,
      lastModified: document.lastModified,
      version: document.version,
      syncState: document.syncState,
      conflictId: document.conflictId,
      deleted: document.deleted,
      deletedAt: document.deletedAt,
      contentHash: document.contentHash,
      fileAttachments: document.fileAttachments,
    );

    _logInfo('Retrying with new sync ID: $newSyncId');

    // Create retry request
    final retryRequest = GraphQLRequest<Document>(
      document: graphQLDocument,
      variables: {
        'input': {
          'syncId': retryDocument.syncId,
          'userId': retryDocument.userId,
          'title': retryDocument.title,
          'category': retryDocument.category,
          'filePaths': retryDocument.filePaths,
          'renewalDate': retryDocument.renewalDate?.format(),
          'notes': retryDocument.notes,
          'createdAt': retryDocument.createdAt.format(),
          'lastModified': retryDocument.lastModified.format(),
          'version': retryDocument.version,
          'syncState': retryDocument.syncState,
          'conflictId': retryDocument.conflictId,
          'deleted': retryDocument.deleted,
          'deletedAt': retryDocument.deletedAt?.format(),
          'contentHash': retryDocument.contentHash,
        }
      },
      decodePath: 'createDocument',
      modelType: Document.classType,
      authorizationMode:
          APIAuthorizationType.userPools, // Use Cognito User Pools
    );

    final retryResponse =
        await Amplify.API.mutate(request: retryRequest).response;

    if (retryResponse.hasErrors) {
      final retryErrors = retryResponse.errors.map((e) => e.message).join(', ');
      _logError('Retry failed: $retryErrors');
      throw Exception('Upload failed after retry: $retryErrors');
    }

    if (retryResponse.data == null) {
      throw Exception('Retry failed: No data returned from server');
    }

    _logInfo(
        'Document uploaded successfully with new sync ID: ${retryDocument.syncId}');
    return retryResponse.data!;
  }

  /// Upload a document to DynamoDB
  /// Creates a new document record in remote storage using syncId as primary key
  ///
  /// **Requirements:**
  /// - Document MUST have a valid sync identifier (UUID v4 format)
  /// - Sync identifier will be used as the DynamoDB partition key
  /// - Document will be validated before upload
  ///
  /// **Parameters:**
  /// - [document]: Document with sync identifier and all required fields
  ///
  /// **Returns:** Document with confirmed sync identifier and synced state
  ///
  /// **Throws:**
  /// - ArgumentError if document lacks sync identifier or has invalid format
  /// - Exception if upload fails due to network or validation errors
  Future<Document> uploadDocument(Document document) async {
    final operationId =
        'upload_${document.syncId}_${DateTime.now().millisecondsSinceEpoch}';
    _performanceMonitor.startOperation(operationId, 'document_upload');

    try {
      return await _authManager.executeWithTokenRefresh(() async {
        return await _retryManager.executeWithRetry(
          () async {
            // Validate authentication before operation
            await _authManager.validateTokenBeforeOperation();

            // Validate document before upload
            _validationService.validateDocumentForUpload(document);

            // Ensure document has a sync identifier and validate it
            if (document.syncId.isEmpty) {
              throw ArgumentError(
                  'Document must have a sync identifier for upload. '
                  'Document: "${document.title}" (syncId: ${document.syncId})');
            }

            // Validate sync identifier format
            SyncIdentifierService.validateOrThrow(document.syncId,
                context: 'document upload');

            // Sanitize document input
            final sanitizedDocument =
                _validationService.sanitizeDocument(document);

            // Create the document with synced state using syncId as primary key
            final documentToUpload = sanitizedDocument.copyWith(
              syncState: SyncState.synced.toJson(),
            );

            _logInfo('Ã°Å¸â€œâ€¹ Document syncId: ${documentToUpload.syncId}');
            _logInfo('Ã°Å¸â€œâ€¹ Document title: ${documentToUpload.title}');

            // Use Amplify API to create document in DynamoDB via GraphQL
            const graphQLDocument = '''
            mutation CreateDocument(\$input: CreateDocumentInput!) {
              createDocument(input: \$input) {
                syncId
                userId
                title
                category
                filePaths
                renewalDate
                notes
                createdAt
                lastModified
                version
                syncState
                conflictId
                deleted
                deletedAt
                contentHash
              }
            }
          ''';

            final request = GraphQLRequest<Document>(
              document: graphQLDocument,
              variables: {
                'input': {
                  'syncId': documentToUpload.syncId,
                  'userId': documentToUpload.userId,
                  'title': documentToUpload.title,
                  'category': documentToUpload.category,
                  'filePaths': documentToUpload.filePaths,
                  'renewalDate': documentToUpload.renewalDate?.format(),
                  'notes': documentToUpload.notes,
                  'createdAt': documentToUpload.createdAt.format(),
                  'lastModified': documentToUpload.lastModified.format(),
                  'version': documentToUpload.version,
                  'syncState': documentToUpload.syncState,
                  'conflictId': documentToUpload.conflictId,
                  'deleted': documentToUpload.deleted,
                  'deletedAt': documentToUpload.deletedAt?.format(),
                  'contentHash': documentToUpload.contentHash,
                }
              },
              decodePath: 'createDocument',
              modelType: Document.classType,
              authorizationMode: APIAuthorizationType.userPools,
            );

            _logInfo('Ã°Å¸â€œÂ¤ Sending GraphQL mutation to DynamoDB...');
            _logInfo('Ã°Å¸â€œâ€¹ Document data: ${documentToUpload.title}');
            _logInfo('Ã°Å¸â€˜Â¤ User ID: ${documentToUpload.userId}');
            _logInfo('Ã°Å¸â€â€˜ Sync ID: ${documentToUpload.syncId}');
            _logInfo('Ã°Å¸â€œÂ File paths: ${documentToUpload.filePaths}');

            final response =
                await Amplify.API.mutate(request: request).response;

            _logInfo('Ã°Å¸â€œÂ¨ GraphQL response received');
            _logInfo('Ã¢Ââ€œ Has errors: ${response.hasErrors}');

            if (response.hasErrors) {
              _logError(
                  'Ã¢ÂÅ’ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
              throw Exception(
                  'Upload failed: ${response.errors.map((e) => e.message).join(', ')}');
            }

            if (response.data == null) {
              _logError('Ã¢ÂÅ’ No data returned from GraphQL mutation');
              throw Exception('Upload failed: No data returned from server');
            }

            _logInfo('Ã¢Å“â€¦ Document successfully created in DynamoDB');
            _logInfo(
                'Ã°Å¸â€â€˜ Created document syncId: ${response.data?.syncId}');

            if (response.data == null) {
              throw Exception('Upload failed: No data returned from server');
            }

            _logInfo('Document uploaded successfully: ${document.syncId}');

            // Sync FileAttachments for this document to DynamoDB
            try {
              _logInfo(
                  '🔄 Starting FileAttachment sync for document: ${document.syncId}');
              await _fileAttachmentSyncManager
                  .syncFileAttachmentsForDocument(document.syncId);
              _logInfo(
                  '✅ FileAttachment sync completed for document: ${document.syncId}');
            } catch (e) {
              _logWarning(
                  '⚠️ FileAttachment sync failed for document ${document.syncId}: $e');
              // Don't fail the entire document upload if FileAttachment sync fails
            }

            // Return the document with the syncId as identifier
            return response.data!;
          },
          config: RetryManager.networkRetryConfig,
        );
      });

      _performanceMonitor.endOperationSuccess(operationId, 'document_upload');
    } catch (e) {
      _performanceMonitor.endOperationFailure(
          operationId, 'document_upload', e.toString());
      rethrow;
    }
  }

  /// Download a document from DynamoDB by syncId
  ///
  /// **Requirements:**
  /// - [syncId] MUST be a valid UUID v4 format
  /// - Document with the sync identifier MUST exist in DynamoDB
  ///
  /// **Parameters:**
  /// - [syncId]: Valid UUID v4 sync identifier
  ///
  /// **Returns:** Document with all fields populated from remote storage
  ///
  /// **Throws:**
  /// - Exception if sync identifier format is invalid
  /// - Exception if document not found
  /// - Exception if download fails due to network errors
  Future<Document> downloadDocument(String syncId) async {
    // Validate sync identifier format
    SyncIdentifierService.validateOrThrow(syncId, context: 'document download');

    final operationId =
        'download_${syncId}_${DateTime.now().millisecondsSinceEpoch}';
    _performanceMonitor.startOperation(operationId, 'document_download');

    try {
      final result = await _authManager.executeWithTokenRefresh(() async {
        return await _retryManager.executeWithRetry(
          () async {
            // Validate authentication before operation
            await _authManager.validateTokenBeforeOperation();

            // Use Amplify API to get document from DynamoDB via GraphQL using syncId
            const graphQLDocument = '''
          query GetDocument(\$syncId: String!) {
            getDocument(syncId: \$syncId) {
              syncId
              userId
              title
              category
              filePaths
              renewalDate
              notes
              createdAt
              lastModified
              version
              syncState
              conflictId
              deleted
              deletedAt
              contentHash
              fileAttachments {
                items {
                  syncId
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
        ''';

            final request = GraphQLRequest<Document>(
              document: graphQLDocument,
              variables: {'syncId': syncId},
              decodePath: 'getDocument',
              modelType: Document.classType,
              authorizationMode: APIAuthorizationType.userPools,
            );

            final response = await Amplify.API.query(request: request).response;

            if (response.hasErrors) {
              throw Exception(
                  'Download failed: ${response.errors.map((e) => e.message).join(', ')}');
            }

            if (response.data == null) {
              throw Exception('Document not found: $syncId');
            }

            // Validate downloaded document structure
            _validationService
                .validateDownloadedDocument(response.data!.toJson());

            _logInfo('Document downloaded successfully: $syncId');
            return response.data!;
          },
          config: RetryManager.networkRetryConfig,
          shouldRetry: (error) {
            // Don't retry if document is not found (404-like error)
            final errorString = error.toString().toLowerCase();
            if (errorString.contains('not found') ||
                errorString.contains('404')) {
              return false;
            }
            return true; // Use default retry logic for other errors
          },
        );
      });

      _performanceMonitor.endOperationSuccess(operationId, 'document_download');
      return result;
    } catch (e) {
      _performanceMonitor.endOperationFailure(
          operationId, 'document_download', e.toString());
      rethrow;
    }
  }

  /// Update a document in DynamoDB with version checking using syncId
  ///
  /// **Requirements:**
  /// - Document MUST have a valid sync identifier (UUID v4 format)
  /// - Version checking is performed to detect conflicts
  /// - Document will be validated before update
  ///
  /// **Parameters:**
  /// - [document]: Document with sync identifier and updated fields
  ///
  /// **Throws:**
  /// - Exception if document lacks sync identifier
  /// - VersionConflictException if versions don't match
  /// - Exception if update fails due to network or validation errors
  Future<void> updateDocument(Document document) async {
    return await _authManager.executeWithTokenRefresh(() async {
      return await _retryManager.executeWithRetry(
        () async {
          // Validate authentication before operation
          await _authManager.validateTokenBeforeOperation();

          // Validate document before update
          _validationService.validateDocumentForUpdate(document);

          // Ensure document has a sync identifier
          if (document.syncId.isEmpty) {
            throw Exception('Document must have a sync identifier for update');
          }

          // Sanitize document input
          final sanitizedDocument =
              _validationService.sanitizeDocument(document);

          // Fetch current version from DynamoDB using syncId
          final remoteDocument =
              await downloadDocument(sanitizedDocument.syncId);

          // Check for version conflict
          if (remoteDocument.version != sanitizedDocument.version) {
            // Register the conflict with the conflict manager
            _conflictManager.detectConflict(
              sanitizedDocument.syncId,
              sanitizedDocument,
              remoteDocument,
            );

            throw VersionConflictException(
              message:
                  'Version conflict detected for document ${sanitizedDocument.syncId}',
              localDocument: sanitizedDocument,
              remoteDocument: remoteDocument,
            );
          }

          // Increment version and update lastModified for the update
          final updatedDocument = sanitizedDocument.copyWith(
            version: sanitizedDocument.version + 1,
            lastModified: amplify_core.TemporalDateTime.now(),
            syncState: SyncState.synced.toJson(),
          );

          // Use Amplify API to update document in DynamoDB via GraphQL using syncId
          const graphQLDocument = '''
          mutation UpdateDocument(\$input: UpdateDocumentInput!) {
            updateDocument(input: \$input) {
              syncId
              userId
              title
              category
              filePaths
              renewalDate
              notes
              createdAt
              lastModified
              version
              syncState
              conflictId
              deleted
              deletedAt
              contentHash
            }
          }
        ''';

          final request = GraphQLRequest<Document>(
            document: graphQLDocument,
            variables: {
              'input': {
                'syncId': updatedDocument.syncId,
                'userId': updatedDocument.userId,
                'title': updatedDocument.title,
                'category': updatedDocument.category,
                'filePaths': updatedDocument.filePaths,
                'renewalDate': updatedDocument.renewalDate?.format(),
                'notes': updatedDocument.notes,
                'createdAt': updatedDocument.createdAt.format(),
                'lastModified': updatedDocument.lastModified.format(),
                'version': updatedDocument.version,
                'syncState': updatedDocument.syncState,
                'conflictId': updatedDocument.conflictId,
                'deleted': updatedDocument.deleted,
                'deletedAt': updatedDocument.deletedAt?.format(),
                'contentHash': updatedDocument.contentHash,
              }
            },
            decodePath: 'updateDocument',
            modelType: Document.classType,
            authorizationMode: APIAuthorizationType.userPools,
          );

          final response = await Amplify.API.mutate(request: request).response;

          if (response.hasErrors) {
            throw Exception(
                'Update failed: ${response.errors.map((e) => e.message).join(', ')}');
          }

          if (response.data == null) {
            throw Exception('Update failed: No data returned from server');
          }

          _logInfo('Document updated successfully: ${document.syncId}');
        },
        config: RetryManager.networkRetryConfig,
        shouldRetry: (error) {
          // Don't retry version conflicts - they need manual resolution
          if (error is VersionConflictException) {
            return false;
          }
          return true; // Use default retry logic for other errors
        },
      );
    });
  }

  /// Delete a document from DynamoDB (soft delete) using syncId
  ///
  /// **Requirements:**
  /// - [syncId] MUST be a valid UUID v4 format
  /// - Document with the sync identifier MUST exist in DynamoDB
  /// - Performs soft delete by marking document as deleted
  ///
  /// **Parameters:**
  /// - [syncId]: Valid UUID v4 sync identifier of document to delete
  ///
  /// **Behavior:**
  /// - Fetches current document to get latest version
  /// - Marks document as deleted with timestamp
  /// - Increments version number for conflict detection
  /// - Preserves document data for tombstone tracking
  ///
  /// **Throws:**
  /// - Exception if sync identifier format is invalid
  /// - Exception if document not found
  /// - Exception if delete fails due to network errors
  Future<void> deleteDocument(String syncId) async {
    // Validate sync identifier format
    SyncIdentifierService.validateOrThrow(syncId, context: 'document deletion');

    try {
      // Fetch the document first using syncId
      final document = await downloadDocument(syncId);

      // Mark as deleted by updating with a deleted flag
      final deletedDocument = document.copyWith(
        lastModified: amplify_core.TemporalDateTime.now(),
        version: document.version + 1,
        syncState: SyncState.synced.toJson(),
        deleted: true,
        deletedAt: amplify_core.TemporalDateTime.now(),
      );

      // Use Amplify API to update document in DynamoDB via GraphQL (soft delete)
      const graphQLDocument = '''
        mutation UpdateDocument(\$input: UpdateDocumentInput!) {
          updateDocument(input: \$input) {
            syncId
            userId
            title
            category
            filePaths
            renewalDate
            notes
            createdAt
            lastModified
            version
            syncState
            conflictId
            deleted
            deletedAt
            contentHash
          }
        }
      ''';

      final request = GraphQLRequest<Document>(
        document: graphQLDocument,
        variables: {
          'input': {
            'syncId': deletedDocument.syncId,
            'userId': deletedDocument.userId,
            'title': deletedDocument.title,
            'category': deletedDocument.category,
            'filePaths': deletedDocument.filePaths,
            'renewalDate': deletedDocument.renewalDate?.format(),
            'notes': deletedDocument.notes,
            'createdAt': deletedDocument.createdAt.format(),
            'lastModified': deletedDocument.lastModified.format(),
            'version': deletedDocument.version,
            'syncState': deletedDocument.syncState,
            'conflictId': deletedDocument.conflictId,
            'deleted': deletedDocument.deleted,
            'deletedAt': deletedDocument.deletedAt?.format(),
            'contentHash': deletedDocument.contentHash,
          }
        },
        decodePath: 'updateDocument',
        modelType: Document.classType,
        authorizationMode: APIAuthorizationType.userPools,
      );

      _logInfo(
          'Ã°Å¸â€”â€˜Ã¯Â¸Â Sending delete mutation to DynamoDB for document: $syncId');
      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        _logError(
            'Ã¢ÂÅ’ Delete mutation errors: ${response.errors.map((e) => e.message).join(', ')}');
        throw Exception(
            'Delete failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        _logError('Ã¢ÂÅ’ Delete mutation returned no data');
        throw Exception('Delete failed: No data returned from server');
      }

      final updatedDoc = response.data!;
      _logInfo('Ã¢Å“â€¦ Document deletion mutation successful: $syncId');
      _logInfo(
          'Ã°Å¸â€Â Updated document deleted flag: ${updatedDoc.deleted}');
      _logInfo('Ã°Å¸â€Â Updated document deletedAt: ${updatedDoc.deletedAt}');
      _logInfo('Ã°Å¸â€Â Updated document version: ${updatedDoc.version}');
    } catch (e) {
      _logError('Error deleting document: $e');
      rethrow;
    }
  }

  /// Fetch all documents for the current user from DynamoDB using owner authorization
  /// Used for initial sync when setting up a new device
  Future<List<Document>> fetchAllDocuments(String userId) async {
    try {
      // Validate user is authenticated
      final authSession = await Amplify.Auth.fetchAuthSession();
      if (!authSession.isSignedIn) {
        throw Exception('User not authenticated');
      }

      // Get current user to verify identity
      final currentUser = await Amplify.Auth.getCurrentUser();
      _logInfo('Fetching documents for user: ${currentUser.userId}');

      // Query DynamoDB for all documents belonging to the authenticated user
      // The @auth(rules: [{allow: owner}]) rule automatically filters by owner
      const graphQLDocument = '''
        query ListDocuments {
          listDocuments(filter: {deleted: {ne: true}}) {
            items {
              syncId
              userId
              title
              category
              filePaths
              renewalDate
              notes
              createdAt
              lastModified
              version
              syncState
              conflictId
              deleted
              deletedAt
              contentHash
              fileAttachments {
                items {
                  syncId
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

      final request = GraphQLRequest<PaginatedResult<Document>>(
        document: graphQLDocument,
        variables: {}, // No variables needed - owner auth handles filtering
        decodePath: 'listDocuments',
        modelType: const PaginatedModelType(Document.classType),
        authorizationMode: APIAuthorizationType.userPools, // Force Cognito auth
      );

      final response = await Amplify.API.query(request: request).response;

      if (response.hasErrors) {
        throw Exception(
            'Fetch failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      final documents = response.data?.items
              .where((doc) => doc != null)
              .cast<Document>()
              .toList() ??
          [];

      _logInfo('Fetched ${documents.length} documents for user $userId');
      return documents;
    } catch (e) {
      _logError('Error fetching all documents: $e');
      rethrow;
    }
  }

  /// Get the sync state of a document using syncId
  Future<SyncState> getDocumentSyncState(String syncId) async {
    // Validate sync identifier format
    SyncIdentifierService.validateOrThrow(syncId,
        context: 'sync state retrieval');

    try {
      final document = await downloadDocument(syncId);
      return SyncState.fromJson(document.syncState);
    } catch (e) {
      _logError('Error getting document sync state for syncId "$syncId": $e');
      return SyncState.error;
    }
  }

  /// Execute an operation with error state management using syncId
  /// Marks documents as error state if max retries are exceeded
  Future<T> _executeWithErrorHandling<T>(
    String syncId,
    String operation,
    Future<T> Function() operationFunction,
  ) async {
    try {
      // Check if document is already in error state and can be retried
      if (_errorManager.isDocumentInError(syncId)) {
        if (!_errorManager.canAttemptRecovery(syncId)) {
          final error = _errorManager.getDocumentError(syncId)!;
          throw Exception(
              'Document in error state: ${error.getUserFriendlyMessage()}');
        }
        // Clear error state for retry attempt
        _errorManager.clearDocumentError(syncId);
      }

      // Execute the operation
      final result = await operationFunction();

      // Clear any previous error state on success
      _errorManager.clearDocumentError(syncId);

      return result;
    } catch (e) {
      // Increment retry count
      _errorManager.incrementRetryCount(syncId);
      final retryCount = _errorManager.getRetryCount(syncId);

      // Check if max retries exceeded
      if (_errorManager.hasExceededMaxRetries(syncId)) {
        _errorManager.markDocumentError(
          syncId,
          e.toString(),
          retryCount: retryCount,
          lastOperation: operation,
          originalError: e,
        );

        _logError(
            'Document $syncId marked as error after $retryCount retries: $e');
      }

      rethrow;
    }
  }

  /// Batch upload multiple documents to DynamoDB using syncId as primary key
  /// Uploads up to 25 documents in a single request for efficiency
  Future<void> batchUploadDocuments(List<Document> documents) async {
    if (documents.isEmpty) {
      return;
    }

    try {
      // Process documents in batches - GraphQL doesn't support batch mutations
      // so we'll use concurrent individual uploads for efficiency
      const batchSize =
          10; // Limit concurrent operations to avoid overwhelming the API

      for (int i = 0; i < documents.length; i += batchSize) {
        final batch = documents.skip(i).take(batchSize).toList();

        // Validate and sanitize all documents in batch
        final documentsToUpload = <Document>[];
        for (final document in batch) {
          // Ensure document has a sync identifier
          if (document.syncId.isEmpty) {
            throw Exception(
                'Document must have a sync identifier for batch upload');
          }

          _validationService.validateDocumentForUpload(document);
          final sanitizedDocument =
              _validationService.sanitizeDocument(document);
          documentsToUpload.add(
              sanitizedDocument.copyWith(syncState: SyncState.synced.toJson()));
        }

        // Execute batch upload using concurrent futures
        final uploadFutures = documentsToUpload.map((document) async {
          const graphQLDocument = '''
            mutation CreateDocument(\$input: CreateDocumentInput!) {
              createDocument(input: \$input) {
                syncId
                userId
                title
                category
                filePaths
                renewalDate
                notes
                createdAt
                lastModified
                version
                syncState
                conflictId
                deleted
                deletedAt
                contentHash
              }
            }
          ''';

          final request = GraphQLRequest<Document>(
            document: graphQLDocument,
            variables: {
              'input': {
                'syncId': document.syncId,
                'userId': document.userId,
                'title': document.title,
                'category': document.category,
                'filePaths': document.filePaths,
                'renewalDate': document.renewalDate?.format(),
                'notes': document.notes,
                'createdAt': document.createdAt.format(),
                'lastModified': document.lastModified.format(),
                'version': document.version,
                'syncState': document.syncState,
                'conflictId': document.conflictId,
                'deleted': document.deleted,
                'deletedAt': document.deletedAt?.format(),
                'contentHash': document.contentHash,
              }
            },
            decodePath: 'createDocument',
            modelType: Document.classType,
            authorizationMode: APIAuthorizationType.userPools,
          );

          final response = await Amplify.API.mutate(request: request).response;

          if (response.hasErrors) {
            throw Exception(
                'Upload failed for ${document.syncId}: ${response.errors.map((e) => e.message).join(', ')}');
          }

          return response.data;
        });

        // Wait for all uploads in this batch to complete
        await Future.wait(uploadFutures);

        // Sync FileAttachments for all documents in this batch
        for (final document in documentsToUpload) {
          try {
            _logInfo(
                '🔄 Starting FileAttachment sync for batch document: ${document.syncId}');
            await _fileAttachmentSyncManager
                .syncFileAttachmentsForDocument(document.syncId);
            _logInfo(
                '✅ FileAttachment sync completed for batch document: ${document.syncId}');
          } catch (e) {
            _logWarning(
                '⚠️ FileAttachment sync failed for batch document ${document.syncId}: $e');
            // Continue with other documents even if FileAttachment sync fails
          }
        }

        _logInfo('Batch uploaded ${batch.length} documents');
      }

      _logInfo('Successfully batch uploaded ${documents.length} documents');
    } catch (e) {
      _logError('Error batch uploading documents: $e');
      rethrow;
    }
  }

  /// Update a document with delta sync - only send changed fields using syncId
  /// More efficient than sending the entire document
  Future<void> updateDocumentDelta(
    Document document,
    Map<String, dynamic> changedFields,
  ) async {
    try {
      // Validate document before update
      _validationService.validateDocumentForUpdate(document);

      // Ensure document has a sync identifier
      if (document.syncId == null || document.syncId!.isEmpty) {
        throw Exception(
            'Document must have a sync identifier for delta update');
      }

      // Sanitize document input
      final sanitizedDocument = _validationService.sanitizeDocument(document);

      // Fetch current version from DynamoDB using syncId
      final remoteDocument = await downloadDocument(sanitizedDocument.syncId!);

      // Check for version conflict
      if (remoteDocument.version != sanitizedDocument.version) {
        // Register the conflict with the conflict manager
        _conflictManager.detectConflict(
          sanitizedDocument.syncId!,
          sanitizedDocument,
          remoteDocument,
        );

        throw VersionConflictException(
          message:
              'Version conflict detected for document ${sanitizedDocument.syncId}',
          localDocument: sanitizedDocument,
          remoteDocument: remoteDocument,
        );
      }

      // Apply changed fields to the document
      var updatedDocument = sanitizedDocument.copyWith(
        lastModified: amplify_core.TemporalDateTime.now(),
        version: sanitizedDocument.version + 1,
        syncState: SyncState.synced.toJson(),
      );

      // Apply specific field changes with sanitization
      if (changedFields.containsKey('title')) {
        final sanitizedTitle =
            _validationService.sanitizeTextInput(changedFields['title']);
        updatedDocument = updatedDocument.copyWith(title: sanitizedTitle);
      }
      if (changedFields.containsKey('category')) {
        final sanitizedCategory =
            _validationService.sanitizeTextInput(changedFields['category']);
        updatedDocument = updatedDocument.copyWith(category: sanitizedCategory);
      }
      if (changedFields.containsKey('notes')) {
        final sanitizedNotes = changedFields['notes'] != null
            ? _validationService.sanitizeTextInput(changedFields['notes'])
            : null;
        updatedDocument = updatedDocument.copyWith(notes: sanitizedNotes);
      }
      if (changedFields.containsKey('renewalDate')) {
        final renewalDate = changedFields['renewalDate'];
        updatedDocument = updatedDocument.copyWith(
            renewalDate: renewalDate != null
                ? amplify_core.TemporalDateTime.fromString(renewalDate)
                : null);
      }
      if (changedFields.containsKey('filePaths')) {
        final sanitizedFilePaths = (changedFields['filePaths'] as List<String>)
            .map((path) => _validationService.sanitizeTextInput(path))
            .toList();
        updatedDocument =
            updatedDocument.copyWith(filePaths: sanitizedFilePaths);
      }

      // Use Amplify API to update document in DynamoDB via GraphQL using syncId
      const graphQLDocument = '''
        mutation UpdateDocument(\$input: UpdateDocumentInput!) {
          updateDocument(input: \$input) {
            syncId
            userId
            title
            category
            filePaths
            renewalDate
            notes
            createdAt
            lastModified
            version
            syncState
            conflictId
            deleted
            deletedAt
            contentHash
          }
        }
      ''';

      final request = GraphQLRequest<Document>(
        document: graphQLDocument,
        variables: {
          'input': {
            'syncId': updatedDocument.syncId,
            'userId': updatedDocument.userId,
            'title': updatedDocument.title,
            'category': updatedDocument.category,
            'filePaths': updatedDocument.filePaths,
            'renewalDate': updatedDocument.renewalDate?.format(),
            'notes': updatedDocument.notes,
            'createdAt': updatedDocument.createdAt.format(),
            'lastModified': updatedDocument.lastModified.format(),
            'version': updatedDocument.version,
            'syncState': updatedDocument.syncState,
            'conflictId': updatedDocument.conflictId,
            'deleted': updatedDocument.deleted,
            'deletedAt': updatedDocument.deletedAt?.format(),
            'contentHash': updatedDocument.contentHash,
          }
        },
        decodePath: 'updateDocument',
        modelType: Document.classType,
        authorizationMode: APIAuthorizationType.userPools,
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw Exception(
            'Delta update failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        throw Exception('Delta update failed: No data returned from server');
      }

      _logInfo(
          'Document updated with delta sync: ${sanitizedDocument.syncId}, fields: ${changedFields.keys.join(", ")}');
    } on VersionConflictException {
      rethrow;
    } catch (e) {
      _logError('Error updating document with delta: $e');
      rethrow;
    }
  }

  /// Get documents that are in error state
  List<DocumentError> getErrorDocuments() {
    return _errorManager.getAllErrorDocuments();
  }

  /// Get error information for a specific document
  DocumentError? getDocumentError(String documentId) {
    return _errorManager.getDocumentError(documentId);
  }

  /// Check if a document is in error state
  bool isDocumentInError(String documentId) {
    return _errorManager.isDocumentInError(documentId);
  }

  /// Clear error state for a document
  void clearDocumentError(String documentId) {
    _errorManager.clearDocumentError(documentId);
  }

  /// Get documents ready for retry
  List<String> getDocumentsReadyForRetry() {
    return _errorManager.getDocumentsReadyForRetry();
  }

  /// Get error statistics
  Map<String, dynamic> getErrorStats() {
    return _errorManager.getErrorStats();
  }

  /// Create a recovery plan for error documents
  Map<String, List<String>> createRecoveryPlan() {
    return _errorManager.createRecoveryPlan();
  }
}
