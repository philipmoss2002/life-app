import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/Document.dart';
import '../utils/sync_identifier_generator.dart';

/// Service for matching documents across storage systems using sync identifiers
///
/// This class provides methods to match documents by sync identifier and
/// calculate content hashes for change detection. It serves as the core
/// component for document identification in the sync system.
class DocumentMatcher {
  /// Match documents by sync identifier (primary method)
  ///
  /// Searches through a list of documents to find one with the specified sync identifier.
  /// This is the primary method for document matching in the sync system.
  ///
  /// Parameters:
  /// - [documents]: List of documents to search through
  /// - [syncId]: The sync identifier to match against
  ///
  /// Returns:
  /// - The matching [Document] if found, null otherwise
  ///
  /// Example:
  /// ```dart
  /// final documents = await getLocalDocuments();
  /// final match = DocumentMatcher.matchBySyncId(documents, "550e8400-e29b-41d4-a716-446655440000");
  /// if (match != null) {
  ///   print("Found document: ${match.title}");
  /// }
  /// ```
  static Document? matchBySyncId(List<Document> documents, String syncId) {
    // Validate the sync identifier format first
    if (!SyncIdentifierGenerator.isValid(syncId)) {
      throw ArgumentError('Invalid sync identifier format: "$syncId". '
          'Expected UUID v4 format (e.g., "550e8400-e29b-41d4-a716-446655440000")');
    }

    // Normalize the sync identifier for consistent matching
    final normalizedSyncId = SyncIdentifierGenerator.normalize(syncId);

    // Find the document with matching sync identifier
    for (final document in documents) {
      final docSyncId = document.syncId;
      if (docSyncId != null) {
        final documentSyncId = SyncIdentifierGenerator.normalize(docSyncId);
        if (documentSyncId == normalizedSyncId) {
          return document;
        }
      }
    }

    return null;
  }

  /// Calculate content hash for change detection
  ///
  /// Generates a SHA-256 hash of the document's content fields to detect changes.
  /// This hash includes all user-modifiable content but excludes metadata like
  /// timestamps, sync state, and system-generated fields.
  ///
  /// The hash is calculated from:
  /// - title
  /// - category
  /// - notes
  /// - filePaths (sorted for consistency)
  ///
  /// Parameters:
  /// - [document]: The document to calculate the hash for
  ///
  /// Returns:
  /// - A hexadecimal string representing the SHA-256 hash of the content
  ///
  /// Example:
  /// ```dart
  /// final document = Document(...);
  /// final hash = DocumentMatcher.calculateContentHash(document);
  /// print("Content hash: $hash");
  /// ```
  static String calculateContentHash(Document document) {
    // Create a map of the content fields that should be included in the hash
    final contentMap = <String, dynamic>{
      'title': document.title,
      'category': document.category,
      'notes': document.notes ?? '',
      // Sort file paths to ensure consistent hashing regardless of order
      'filePaths': List<String>.from(document.filePaths)..sort(),
    };

    // Convert to JSON string for consistent serialization
    final contentJson = json.encode(contentMap);

    // Calculate SHA-256 hash
    final bytes = utf8.encode(contentJson);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  /// Match documents by content hash
  ///
  /// Searches through a list of documents to find ones with the specified content hash.
  /// This method can be used as a fallback when sync identifiers are not available
  /// or for detecting duplicate content.
  ///
  /// Parameters:
  /// - [documents]: List of documents to search through
  /// - [contentHash]: The content hash to match against
  ///
  /// Returns:
  /// - A list of matching [Document]s (can be empty if no matches found)
  ///
  /// Example:
  /// ```dart
  /// final documents = await getLocalDocuments();
  /// final hash = DocumentMatcher.calculateContentHash(someDocument);
  /// final matches = DocumentMatcher.matchByContentHash(documents, hash);
  /// print("Found ${matches.length} documents with matching content");
  /// ```
  static List<Document> matchByContentHash(
      List<Document> documents, String contentHash) {
    final matches = <Document>[];

    for (final document in documents) {
      final documentHash = calculateContentHash(document);
      if (documentHash == contentHash) {
        matches.add(document);
      }
    }

    return matches;
  }

  /// Check if two documents have the same content
  ///
  /// Compares the content of two documents by calculating and comparing their hashes.
  /// This is useful for detecting if documents have identical content regardless
  /// of their identifiers or metadata.
  ///
  /// Parameters:
  /// - [document1]: First document to compare
  /// - [document2]: Second document to compare
  ///
  /// Returns:
  /// - true if the documents have identical content, false otherwise
  ///
  /// Example:
  /// ```dart
  /// final doc1 = Document(...);
  /// final doc2 = Document(...);
  /// if (DocumentMatcher.haveSameContent(doc1, doc2)) {
  ///   print("Documents have identical content");
  /// }
  /// ```
  static bool haveSameContent(Document document1, Document document2) {
    final hash1 = calculateContentHash(document1);
    final hash2 = calculateContentHash(document2);
    return hash1 == hash2;
  }

  /// Find documents without sync identifiers
  ///
  /// Filters a list of documents to find those that don't have sync identifiers.
  /// This is useful during migration to identify documents that need sync identifiers.
  ///
  /// Parameters:
  /// - [documents]: List of documents to filter
  ///
  /// Returns:
  /// - A list of [Document]s that don't have sync identifiers
  ///
  /// Example:
  /// ```dart
  /// final documents = await getLocalDocuments();
  /// final withoutSyncId = DocumentMatcher.findDocumentsWithoutSyncId(documents);
  /// print("Found ${withoutSyncId.length} documents without sync identifiers");
  /// ```
  static List<Document> findDocumentsWithoutSyncId(List<Document> documents) {
    return documents.where((document) {
      final syncId = document.syncId;
      return syncId == null || syncId.isEmpty;
    }).toList();
  }

  /// Validate that all documents in a collection have unique sync identifiers
  ///
  /// Checks that all documents with sync identifiers have unique values.
  /// This is useful for data integrity validation.
  ///
  /// Parameters:
  /// - [documents]: List of documents to validate
  ///
  /// Returns:
  /// - A [ValidationResult] containing details about any duplicate sync identifiers
  ///
  /// Example:
  /// ```dart
  /// final documents = await getLocalDocuments();
  /// final result = DocumentMatcher.validateUniqueSyncIds(documents);
  /// if (!result.isValid) {
  ///   print("Found duplicate sync identifiers: ${result.duplicates}");
  /// }
  /// ```
  static ValidationResult validateUniqueSyncIds(List<Document> documents) {
    final Map<String, List<Document>> syncIdGroups = {};
    final List<Document> duplicates = [];

    // Group documents by sync identifier
    for (final document in documents) {
      final syncId = document.syncId;
      if (syncId != null && syncId.isNotEmpty) {
        final normalizedSyncId = SyncIdentifierGenerator.normalize(syncId);
        syncIdGroups.putIfAbsent(normalizedSyncId, () => []).add(document);
      }
    }

    // Find groups with more than one document (duplicates)
    for (final group in syncIdGroups.values) {
      if (group.length > 1) {
        duplicates.addAll(group);
      }
    }

    return ValidationResult(
      isValid: true,
      duplicates: duplicates,
      totalDocuments: documents.length,
      documentsWithSyncId:
          syncIdGroups.values.fold(0, (sum, group) => sum + group.length),
    );
  }
}

/// Result of document sync identifier validation
class ValidationResult {
  final bool isValid;
  final List<Document> duplicates;
  final int totalDocuments;
  final int documentsWithSyncId;

  const ValidationResult({
    required this.isValid,
    required this.duplicates,
    required this.totalDocuments,
    required this.documentsWithSyncId,
  });

  /// Get a human-readable summary of validation results
  String get summary {
    if (isValid) {
      return 'All $documentsWithSyncId documents with sync identifiers are unique '
          '($totalDocuments total documents)';
    }

    final duplicateCount = duplicates.length;
    final uniqueSyncIds = documentsWithSyncId - duplicateCount;

    return 'Found $duplicateCount documents with duplicate sync identifiers. '
        '$uniqueSyncIds unique sync identifiers out of $totalDocuments total documents.';
  }

  @override
  String toString() => summary;
}
