import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';
import 'retry_manager.dart';
import 'auth_token_manager.dart';
import 'version_conflict_manager.dart';
import 'error_state_manager.dart';
import 'document_validation_service.dart';
import 'performance_monitor.dart';
import 'log_service.dart' as app_log;

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

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);
  void _logDebug(String message) =>
      _logService.log(message, level: app_log.LogLevel.debug);

  /// Upload a document to DynamoDB
  /// Creates a new document record in remote storage
  /// Returns the document with the DynamoDB-generated ID
  Future<Document> uploadDocument(Document document) async {
    final operationId =
        'upload_${document.id}_${DateTime.now().millisecondsSinceEpoch}';
    _performanceMonitor.startOperation(operationId, 'document_upload');

    try {
      return await _authManager.executeWithTokenRefresh(() async {
        return await _retryManager.executeWithRetry(
          () async {
            // Validate authentication before operation
            await _authManager.validateTokenBeforeOperation();

            // Validate document before upload
            _validationService.validateDocumentForUpload(document);

            // Sanitize document input
            final sanitizedDocument =
                _validationService.sanitizeDocument(document);

            // Create the document with synced state and let DynamoDB generate the ID
            final documentToUpload = sanitizedDocument.copyWith(
              syncState: SyncState.synced.toJson(),
            );

            _logInfo('📋 Original document ID: ${documentToUpload.id}');
            _logInfo('📋 Document ID type: ${documentToUpload.id.runtimeType}');

            // Use Amplify API to create document in DynamoDB via GraphQL
            const graphQLDocument = '''
            mutation CreateDocument(\$input: CreateDocumentInput!) {
              createDocument(input: \$input) {
                id
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
              }
            }
          ''';

            final request = GraphQLRequest<Document>(
              document: graphQLDocument,
              variables: {
                'input': {
                  // Don't include 'id' - let DynamoDB auto-generate it
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
                }
              },
              decodePath: 'createDocument',
              modelType: Document.classType,
            );

            _logInfo('📤 Sending GraphQL mutation to DynamoDB...');
            _logInfo('📋 Document data: ${documentToUpload.title}');
            _logInfo('👤 User ID: ${documentToUpload.userId}');
            _logInfo('📁 File paths: ${documentToUpload.filePaths}');

            final response =
                await Amplify.API.mutate(request: request).response;

            _logInfo('📨 GraphQL response received');
            _logInfo('❓ Has errors: ${response.hasErrors}');

            if (response.hasErrors) {
              _logError(
                  '❌ GraphQL errors: ${response.errors.map((e) => e.message).join(', ')}');
              throw Exception(
                  'Upload failed: ${response.errors.map((e) => e.message).join(', ')}');
            }

            if (response.data == null) {
              _logError('❌ No data returned from GraphQL mutation');
              throw Exception('Upload failed: No data returned from server');
            }

            _logInfo('✅ Document successfully created in DynamoDB');
            _logInfo('📄 Created document ID: ${response.data?.id}');

            // If DynamoDB generated a new ID, we should update the local document
            if (response.data?.id != null &&
                response.data!.id != documentToUpload.id) {
              _logInfo('🔄 DynamoDB generated new ID: ${response.data!.id}');
              _logInfo('📝 Original local ID was: ${documentToUpload.id}');
              // Note: The caller should handle updating the local database with the new ID
            }

            if (response.data == null) {
              throw Exception('Upload failed: No data returned from server');
            }

            _logInfo('Document uploaded successfully: ${document.id}');

            // Return the document with the DynamoDB-generated ID
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

  /// Download a document from DynamoDB by ID
  /// Returns the document if found, throws exception otherwise
  Future<Document> downloadDocument(String documentId) async {
    final operationId =
        'download_${documentId}_${DateTime.now().millisecondsSinceEpoch}';
    _performanceMonitor.startOperation(operationId, 'document_download');

    try {
      final result = await _authManager.executeWithTokenRefresh(() async {
        return await _retryManager.executeWithRetry(
          () async {
            // Validate authentication before operation
            await _authManager.validateTokenBeforeOperation();

            // Use Amplify API to get document from DynamoDB via GraphQL
            const graphQLDocument = '''
          query GetDocument(\$id: ID!) {
            getDocument(id: \$id) {
              id
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
            }
          }
        ''';

            final request = GraphQLRequest<Document>(
              document: graphQLDocument,
              variables: {'id': documentId},
              decodePath: 'getDocument',
              modelType: Document.classType,
            );

            final response = await Amplify.API.query(request: request).response;

            if (response.hasErrors) {
              throw Exception(
                  'Download failed: ${response.errors.map((e) => e.message).join(', ')}');
            }

            if (response.data == null) {
              throw Exception('Document not found: $documentId');
            }

            // Validate downloaded document structure
            _validationService
                .validateDownloadedDocument(response.data!.toJson());

            _logInfo('Document downloaded successfully: $documentId');
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

  /// Update a document in DynamoDB with version checking
  /// Throws VersionConflictException if versions don't match
  Future<void> updateDocument(Document document) async {
    return await _authManager.executeWithTokenRefresh(() async {
      return await _retryManager.executeWithRetry(
        () async {
          // Validate authentication before operation
          await _authManager.validateTokenBeforeOperation();

          // Validate document before update
          _validationService.validateDocumentForUpdate(document);

          // Sanitize document input
          final sanitizedDocument =
              _validationService.sanitizeDocument(document);

          // Fetch current version from DynamoDB
          final remoteDocument = await downloadDocument(sanitizedDocument.id);

          // Check for version conflict
          if (remoteDocument.version != sanitizedDocument.version) {
            // Register the conflict with the conflict manager
            _conflictManager.detectConflict(
              sanitizedDocument.id,
              sanitizedDocument,
              remoteDocument,
            );

            throw VersionConflictException(
              message:
                  'Version conflict detected for document ${sanitizedDocument.id}',
              localDocument: sanitizedDocument,
              remoteDocument: remoteDocument,
            );
          }

          // Increment version and update lastModified for the update
          final updatedDocument = sanitizedDocument.copyWith(
            version: sanitizedDocument.version + 1,
            lastModified: TemporalDateTime.now(),
            syncState: SyncState.synced.toJson(),
          );

          // Use Amplify API to update document in DynamoDB via GraphQL
          const graphQLDocument = '''
          mutation UpdateDocument(\$input: UpdateDocumentInput!) {
            updateDocument(input: \$input) {
              id
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
            }
          }
        ''';

          final request = GraphQLRequest<Document>(
            document: graphQLDocument,
            variables: {
              'input': {
                'id': updatedDocument.id,
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
              }
            },
            decodePath: 'updateDocument',
            modelType: Document.classType,
          );

          final response = await Amplify.API.mutate(request: request).response;

          if (response.hasErrors) {
            throw Exception(
                'Update failed: ${response.errors.map((e) => e.message).join(', ')}');
          }

          if (response.data == null) {
            throw Exception('Update failed: No data returned from server');
          }

          _logInfo('Document updated successfully: ${document.id}');
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

  /// Delete a document from DynamoDB (soft delete)
  /// Marks the document as deleted rather than removing it
  Future<void> deleteDocument(String documentId) async {
    try {
      // Fetch the document first
      final document = await downloadDocument(documentId);

      // Mark as deleted by updating with a deleted flag
      final deletedDocument = document.copyWith(
        lastModified: TemporalDateTime.now(),
        version: document.version + 1,
        syncState: SyncState.synced.toJson(),
        deleted: true,
        deletedAt: TemporalDateTime.now(),
      );

      // Use Amplify API to update document in DynamoDB via GraphQL (soft delete)
      const graphQLDocument = '''
        mutation UpdateDocument(\$input: UpdateDocumentInput!) {
          updateDocument(input: \$input) {
            id
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
          }
        }
      ''';

      final request = GraphQLRequest<Document>(
        document: graphQLDocument,
        variables: {
          'input': {
            'id': deletedDocument.id,
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
          }
        },
        decodePath: 'updateDocument',
        modelType: Document.classType,
      );

      final response = await Amplify.API.mutate(request: request).response;

      if (response.hasErrors) {
        throw Exception(
            'Delete failed: ${response.errors.map((e) => e.message).join(', ')}');
      }

      if (response.data == null) {
        throw Exception('Delete failed: No data returned from server');
      }

      _logInfo('Document deleted successfully: $documentId');
    } catch (e) {
      _logError('Error deleting document: $e');
      rethrow;
    }
  }

  /// Fetch all documents for the current user from DynamoDB
  /// Used for initial sync when setting up a new device
  Future<List<Document>> fetchAllDocuments(String userId) async {
    try {
      // Query DynamoDB for all documents belonging to the user via GraphQL
      const graphQLDocument = '''
        query ListDocuments(\$filter: ModelDocumentFilterInput) {
          listDocuments(filter: \$filter) {
            items {
              id
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
            }
          }
        }
      ''';

      final request = GraphQLRequest<PaginatedResult<Document>>(
        document: graphQLDocument,
        variables: {
          'filter': {
            'userId': {'eq': userId},
            'deleted': {'ne': true}
          }
        },
        decodePath: 'listDocuments',
        modelType: const PaginatedModelType(Document.classType),
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

  /// Get the sync state of a document
  Future<SyncState> getDocumentSyncState(String documentId) async {
    try {
      final document = await downloadDocument(documentId);
      return SyncState.fromJson(document.syncState);
    } catch (e) {
      _logError('Error getting document sync state: $e');
      return SyncState.error;
    }
  }

  /// Execute an operation with error state management
  /// Marks documents as error state if max retries are exceeded
  Future<T> _executeWithErrorHandling<T>(
    String documentId,
    String operation,
    Future<T> Function() operationFunction,
  ) async {
    try {
      // Check if document is already in error state and can be retried
      if (_errorManager.isDocumentInError(documentId)) {
        if (!_errorManager.canAttemptRecovery(documentId)) {
          final error = _errorManager.getDocumentError(documentId)!;
          throw Exception(
              'Document in error state: ${error.getUserFriendlyMessage()}');
        }
        // Clear error state for retry attempt
        _errorManager.clearDocumentError(documentId);
      }

      // Execute the operation
      final result = await operationFunction();

      // Clear any previous error state on success
      _errorManager.clearDocumentError(documentId);

      return result;
    } catch (e) {
      // Increment retry count
      _errorManager.incrementRetryCount(documentId);
      final retryCount = _errorManager.getRetryCount(documentId);

      // Check if max retries exceeded
      if (_errorManager.hasExceededMaxRetries(documentId)) {
        _errorManager.markDocumentError(
          documentId,
          e.toString(),
          retryCount: retryCount,
          lastOperation: operation,
          originalError: e,
        );

        _logError(
            'Document $documentId marked as error after $retryCount retries: $e');
      }

      rethrow;
    }
  }

  /// Batch upload multiple documents to DynamoDB
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
                id
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
              }
            }
          ''';

          final request = GraphQLRequest<Document>(
            document: graphQLDocument,
            variables: {
              'input': {
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
              }
            },
            decodePath: 'createDocument',
            modelType: Document.classType,
          );

          final response = await Amplify.API.mutate(request: request).response;

          if (response.hasErrors) {
            throw Exception(
                'Upload failed for ${document.id}: ${response.errors.map((e) => e.message).join(', ')}');
          }

          return response.data;
        });

        // Wait for all uploads in this batch to complete
        await Future.wait(uploadFutures);

        _logInfo('Batch uploaded ${batch.length} documents');
      }

      _logInfo('Successfully batch uploaded ${documents.length} documents');
    } catch (e) {
      _logError('Error batch uploading documents: $e');
      rethrow;
    }
  }

  /// Update a document with delta sync - only send changed fields
  /// More efficient than sending the entire document
  Future<void> updateDocumentDelta(
    Document document,
    Map<String, dynamic> changedFields,
  ) async {
    try {
      // Validate document before update
      _validationService.validateDocumentForUpdate(document);

      // Sanitize document input
      final sanitizedDocument = _validationService.sanitizeDocument(document);

      // Fetch current version from DynamoDB
      final remoteDocument = await downloadDocument(sanitizedDocument.id);

      // Check for version conflict
      if (remoteDocument.version != sanitizedDocument.version) {
        // Register the conflict with the conflict manager
        _conflictManager.detectConflict(
          sanitizedDocument.id,
          sanitizedDocument,
          remoteDocument,
        );

        throw VersionConflictException(
          message:
              'Version conflict detected for document ${sanitizedDocument.id}',
          localDocument: sanitizedDocument,
          remoteDocument: remoteDocument,
        );
      }

      // Apply changed fields to the document
      var updatedDocument = sanitizedDocument.copyWith(
        lastModified: TemporalDateTime.now(),
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
                ? TemporalDateTime.fromString(renewalDate)
                : null);
      }
      if (changedFields.containsKey('filePaths')) {
        final sanitizedFilePaths = (changedFields['filePaths'] as List<String>)
            .map((path) => _validationService.sanitizeTextInput(path))
            .toList();
        updatedDocument =
            updatedDocument.copyWith(filePaths: sanitizedFilePaths);
      }

      // Use Amplify API to update document in DynamoDB via GraphQL
      const graphQLDocument = '''
        mutation UpdateDocument(\$input: UpdateDocumentInput!) {
          updateDocument(input: \$input) {
            id
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
          }
        }
      ''';

      final request = GraphQLRequest<Document>(
        document: graphQLDocument,
        variables: {
          'input': {
            'id': updatedDocument.id,
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
          }
        },
        decodePath: 'updateDocument',
        modelType: Document.classType,
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
          'Document updated with delta sync: ${sanitizedDocument.id}, fields: ${changedFields.keys.join(", ")}');
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
