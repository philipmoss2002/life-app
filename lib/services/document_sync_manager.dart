import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/document.dart';
import '../models/sync_state.dart';

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

  /// Upload a document to DynamoDB
  /// Creates a new document record in remote storage
  Future<void> uploadDocument(Document document) async {
    try {
      // Ensure document has a userId
      if (document.userId == null || document.userId!.isEmpty) {
        throw Exception('Document must have a userId to upload');
      }

      // Create document data for DynamoDB
      final documentData = {
        'id': document.id?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        'userId': document.userId!,
        'title': document.title,
        'category': document.category,
        'filePaths': document.filePaths,
        'renewalDate': document.renewalDate?.toIso8601String(),
        'notes': document.notes,
        'createdAt': document.createdAt.toIso8601String(),
        'lastModified': document.lastModified.toIso8601String(),
        'version': document.version,
        'syncState': SyncState.synced.toJson(),
      };

      // Use Amplify API to put item in DynamoDB
      // Note: This is a simplified implementation
      // In production, you would use GraphQL mutations or REST API
      await _putItemToDynamoDB(documentData);

      safePrint('Document uploaded successfully: ${document.id}');
    } catch (e) {
      safePrint('Error uploading document: $e');
      rethrow;
    }
  }

  /// Download a document from DynamoDB by ID
  /// Returns the document if found, throws exception otherwise
  Future<Document> downloadDocument(String documentId) async {
    try {
      // Use Amplify API to get item from DynamoDB
      final documentData = await _getItemFromDynamoDB(documentId);

      if (documentData == null) {
        throw Exception('Document not found: $documentId');
      }

      // Convert DynamoDB data to Document object
      final document = _documentFromDynamoDB(documentData);

      safePrint('Document downloaded successfully: $documentId');
      return document;
    } catch (e) {
      safePrint('Error downloading document: $e');
      rethrow;
    }
  }

  /// Update a document in DynamoDB with version checking
  /// Throws VersionConflictException if versions don't match
  Future<void> updateDocument(Document document) async {
    try {
      // Ensure document has a userId and id
      if (document.userId == null || document.userId!.isEmpty) {
        throw Exception('Document must have a userId to update');
      }
      if (document.id == null) {
        throw Exception('Document must have an id to update');
      }

      // Fetch current version from DynamoDB
      final remoteDocument = await downloadDocument(document.id.toString());

      // Check for version conflict
      if (remoteDocument.version != document.version) {
        throw VersionConflictException(
          message: 'Version conflict detected for document ${document.id}',
          localDocument: document,
          remoteDocument: remoteDocument,
        );
      }

      // Increment version for the update
      final updatedDocument = document.incrementVersion();

      // Create document data for DynamoDB
      final documentData = {
        'id': updatedDocument.id.toString(),
        'userId': updatedDocument.userId!,
        'title': updatedDocument.title,
        'category': updatedDocument.category,
        'filePaths': updatedDocument.filePaths,
        'renewalDate': updatedDocument.renewalDate?.toIso8601String(),
        'notes': updatedDocument.notes,
        'createdAt': updatedDocument.createdAt.toIso8601String(),
        'lastModified': updatedDocument.lastModified.toIso8601String(),
        'version': updatedDocument.version,
        'syncState': SyncState.synced.toJson(),
      };

      // Update item in DynamoDB
      await _putItemToDynamoDB(documentData);

      safePrint('Document updated successfully: ${document.id}');
    } on VersionConflictException {
      rethrow;
    } catch (e) {
      safePrint('Error updating document: $e');
      rethrow;
    }
  }

  /// Delete a document from DynamoDB (soft delete)
  /// Marks the document as deleted rather than removing it
  Future<void> deleteDocument(String documentId) async {
    try {
      // Fetch the document first
      final document = await downloadDocument(documentId);

      // Mark as deleted by updating with a deleted flag
      final documentData = {
        'id': documentId,
        'userId': document.userId!,
        'title': document.title,
        'category': document.category,
        'filePaths': document.filePaths,
        'renewalDate': document.renewalDate?.toIso8601String(),
        'notes': document.notes,
        'createdAt': document.createdAt.toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
        'version': document.version + 1,
        'syncState': SyncState.synced.toJson(),
        'deleted': true,
        'deletedAt': DateTime.now().toIso8601String(),
      };

      // Update item in DynamoDB with deleted flag
      await _putItemToDynamoDB(documentData);

      safePrint('Document deleted successfully: $documentId');
    } catch (e) {
      safePrint('Error deleting document: $e');
      rethrow;
    }
  }

  /// Fetch all documents for the current user from DynamoDB
  /// Used for initial sync when setting up a new device
  Future<List<Document>> fetchAllDocuments(String userId) async {
    try {
      // Query DynamoDB for all documents belonging to the user
      final documentsData = await _queryDocumentsByUserId(userId);

      // Convert DynamoDB data to Document objects
      final documents = documentsData
          .where(
              (data) => data['deleted'] != true) // Filter out deleted documents
          .map((data) => _documentFromDynamoDB(data))
          .toList();

      safePrint('Fetched ${documents.length} documents for user $userId');
      return documents;
    } catch (e) {
      safePrint('Error fetching all documents: $e');
      rethrow;
    }
  }

  /// Get the sync state of a document
  Future<SyncState> getDocumentSyncState(String documentId) async {
    try {
      final document = await downloadDocument(documentId);
      return document.syncState;
    } catch (e) {
      safePrint('Error getting document sync state: $e');
      return SyncState.error;
    }
  }

  // Private helper methods for DynamoDB operations
  // These would be replaced with actual Amplify API calls in production

  Future<void> _putItemToDynamoDB(Map<String, dynamic> data) async {
    // TODO: Implement actual DynamoDB put operation using Amplify API
    // This is a placeholder that simulates the operation
    // In production, use GraphQL mutation or REST API call
    await Future.delayed(const Duration(milliseconds: 100));
    safePrint('Simulated DynamoDB put: ${data['id']}');
  }

  Future<Map<String, dynamic>?> _getItemFromDynamoDB(String documentId) async {
    // TODO: Implement actual DynamoDB get operation using Amplify API
    // This is a placeholder that simulates the operation
    // In production, use GraphQL query or REST API call
    await Future.delayed(const Duration(milliseconds: 100));
    safePrint('Simulated DynamoDB get: $documentId');

    // Return null to simulate document not found
    // In real implementation, this would query DynamoDB
    return null;
  }

  Future<List<Map<String, dynamic>>> _queryDocumentsByUserId(
      String userId) async {
    // TODO: Implement actual DynamoDB query operation using Amplify API
    // This is a placeholder that simulates the operation
    // In production, use GraphQL query or REST API call
    await Future.delayed(const Duration(milliseconds: 100));
    safePrint('Simulated DynamoDB query for userId: $userId');

    // Return empty list for now
    // In real implementation, this would query DynamoDB
    return [];
  }

  Document _documentFromDynamoDB(Map<String, dynamic> data) {
    return Document(
      id: int.tryParse(data['id'].toString()),
      userId: data['userId'],
      title: data['title'],
      category: data['category'],
      filePaths: (data['filePaths'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      renewalDate: data['renewalDate'] != null
          ? DateTime.parse(data['renewalDate'])
          : null,
      notes: data['notes'],
      createdAt: DateTime.parse(data['createdAt']),
      lastModified: DateTime.parse(data['lastModified']),
      version: data['version'],
      syncState: SyncState.fromJson(data['syncState']),
    );
  }
}
