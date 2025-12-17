import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Document.dart';
import '../models/sync_state.dart';
import 'database_service.dart';
import 'document_sync_manager.dart';
import 'simple_file_sync_manager.dart';
import 'authentication_service.dart';

/// Enum representing migration status
enum MigrationStatus {
  notStarted,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Model representing migration progress
class MigrationProgress {
  final int totalDocuments;
  final int migratedDocuments;
  final int failedDocuments;
  final MigrationStatus status;
  final List<MigrationFailure> failures;
  final String? error;

  MigrationProgress({
    required this.totalDocuments,
    required this.migratedDocuments,
    required this.failedDocuments,
    required this.status,
    this.failures = const [],
    this.error,
  });

  double get progressPercentage {
    if (totalDocuments == 0) return 0.0;
    return (migratedDocuments + failedDocuments) / totalDocuments;
  }

  bool get isComplete => status == MigrationStatus.completed;
  bool get isFailed => status == MigrationStatus.failed;
  bool get isCancelled => status == MigrationStatus.cancelled;
  bool get isInProgress => status == MigrationStatus.inProgress;

  MigrationProgress copyWith({
    int? totalDocuments,
    int? migratedDocuments,
    int? failedDocuments,
    MigrationStatus? status,
    List<MigrationFailure>? failures,
    String? error,
  }) {
    return MigrationProgress(
      totalDocuments: totalDocuments ?? this.totalDocuments,
      migratedDocuments: migratedDocuments ?? this.migratedDocuments,
      failedDocuments: failedDocuments ?? this.failedDocuments,
      status: status ?? this.status,
      failures: failures ?? this.failures,
      error: error ?? this.error,
    );
  }
}

/// Model representing a migration failure
class MigrationFailure {
  final String documentId;
  final String documentTitle;
  final String error;
  final DateTime failedAt;
  final int retryCount;

  MigrationFailure({
    required this.documentId,
    required this.documentTitle,
    required this.error,
    DateTime? failedAt,
    this.retryCount = 0,
  }) : failedAt = failedAt ?? DateTime.now();

  MigrationFailure copyWith({
    String? documentId,
    String? documentTitle,
    String? error,
    DateTime? failedAt,
    int? retryCount,
  }) {
    return MigrationFailure(
      documentId: documentId ?? this.documentId,
      documentTitle: documentTitle ?? this.documentTitle,
      error: error ?? this.error,
      failedAt: failedAt ?? this.failedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Service for migrating local documents to cloud storage
/// Handles the migration workflow when a user upgrades to premium
class MigrationService {
  static final MigrationService _instance = MigrationService._internal();
  factory MigrationService() => _instance;
  MigrationService._internal();

  // Dependencies
  final DatabaseService _databaseService = DatabaseService.instance;
  final DocumentSyncManager _documentSyncManager = DocumentSyncManager();
  final SimpleFileSyncManager _fileSyncManager = SimpleFileSyncManager();
  final AuthenticationService _authService = AuthenticationService();

  // State
  MigrationProgress _progress = MigrationProgress(
    totalDocuments: 0,
    migratedDocuments: 0,
    failedDocuments: 0,
    status: MigrationStatus.notStarted,
  );

  bool _isCancelled = false;

  // Progress streaming
  final StreamController<MigrationProgress> _progressController =
      StreamController<MigrationProgress>.broadcast();

  /// Stream of migration progress updates
  Stream<MigrationProgress> get progressStream => _progressController.stream;

  /// Get current migration progress
  MigrationProgress get currentProgress => _progress;

  /// Start the migration process
  /// Uploads all local documents to cloud storage
  Future<MigrationProgress> startMigration() async {
    try {
      // Check if user is authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to start migration');
      }

      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('Could not get current user');
      }

      // Reset cancellation flag
      _isCancelled = false;

      // Get all local documents
      final localDocuments = await _databaseService.getAllDocuments();

      // Initialize progress
      _progress = MigrationProgress(
        totalDocuments: localDocuments.length,
        migratedDocuments: 0,
        failedDocuments: 0,
        status: MigrationStatus.inProgress,
      );
      _emitProgress();

      safePrint('Starting migration of ${localDocuments.length} documents');

      // Migrate each document
      final failures = <MigrationFailure>[];
      int migratedCount = 0;

      for (final document in localDocuments) {
        // Check if migration was cancelled
        if (_isCancelled) {
          _progress = _progress.copyWith(
            status: MigrationStatus.cancelled,
          );
          _emitProgress();
          safePrint('Migration cancelled by user');
          return _progress;
        }

        try {
          // Add userId to document if not present
          final documentWithUserId = document.copyWith(userId: user.id);

          // Migrate the document
          await _migrateDocument(documentWithUserId);

          migratedCount++;
          _progress = _progress.copyWith(
            migratedDocuments: migratedCount,
          );
          _emitProgress();

          safePrint(
              'Migrated document ${document.id}: ${document.title} ($migratedCount/${localDocuments.length})');
        } catch (e) {
          safePrint('Failed to migrate document ${document.id}: $e');

          final failure = MigrationFailure(
            documentId: document.id.toString(),
            documentTitle: document.title,
            error: e.toString(),
          );
          failures.add(failure);

          _progress = _progress.copyWith(
            failedDocuments: failures.length,
            failures: failures,
          );
          _emitProgress();
        }
      }

      // Verify migration
      await _verifyMigration(localDocuments, failures);

      // Update final status
      final finalStatus = failures.isEmpty
          ? MigrationStatus.completed
          : (migratedCount > 0
              ? MigrationStatus.completed
              : MigrationStatus.failed);

      _progress = _progress.copyWith(
        status: finalStatus,
      );
      _emitProgress();

      safePrint(
          'Migration completed: $migratedCount succeeded, ${failures.length} failed');

      return _progress;
    } catch (e) {
      safePrint('Migration failed with error: $e');

      _progress = _progress.copyWith(
        status: MigrationStatus.failed,
        error: e.toString(),
      );
      _emitProgress();

      return _progress;
    }
  }

  /// Cancel the ongoing migration
  Future<void> cancelMigration() async {
    if (_progress.status != MigrationStatus.inProgress) {
      safePrint('No migration in progress to cancel');
      return;
    }

    safePrint('Cancelling migration');
    _isCancelled = true;
  }

  /// Retry failed documents
  /// Attempts to migrate documents that failed in the previous migration
  Future<MigrationProgress> retryFailedDocuments() async {
    if (_progress.failures.isEmpty) {
      safePrint('No failed documents to retry');
      return _progress;
    }

    try {
      // Check if user is authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      if (!isAuthenticated) {
        throw Exception('User must be authenticated to retry migration');
      }

      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('Could not get current user');
      }

      safePrint('Retrying ${_progress.failures.length} failed documents');

      // Update status to in progress
      _progress = _progress.copyWith(
        status: MigrationStatus.inProgress,
      );
      _emitProgress();

      // Get all local documents
      final localDocuments = await _databaseService.getAllDocuments();

      // Retry each failed document
      final remainingFailures = <MigrationFailure>[];
      int retriedCount = 0;

      for (final failure in _progress.failures) {
        // Check if migration was cancelled
        if (_isCancelled) {
          _progress = _progress.copyWith(
            status: MigrationStatus.cancelled,
          );
          _emitProgress();
          return _progress;
        }

        try {
          // Find the document in local database
          final document = localDocuments.firstWhere(
            (doc) => doc.id.toString() == failure.documentId,
            orElse: () => Document(
              userId: 'unknown',
              title: '',
              category: '',
              filePaths: [],
              createdAt: amplify_core.TemporalDateTime.now(),
              lastModified: amplify_core.TemporalDateTime.now(),
              version: 0,
              syncState: SyncState.notSynced.toJson(),
            ),
          );

          if (document.title.isEmpty) {
            // Document not found, skip
            safePrint('Document ${failure.documentId} not found, skipping');
            continue;
          }

          // Add userId to document if not present
          final documentWithUserId = document.copyWith(userId: user.id);

          // Retry migration
          await _migrateDocument(documentWithUserId);

          retriedCount++;
          _progress = _progress.copyWith(
            migratedDocuments: _progress.migratedDocuments + 1,
            failedDocuments: _progress.failedDocuments - 1,
          );
          _emitProgress();

          safePrint('Successfully retried document ${document.id}');
        } catch (e) {
          safePrint('Failed to retry document ${failure.documentId}: $e');

          // Increment retry count
          final updatedFailure = failure.copyWith(
            retryCount: failure.retryCount + 1,
            error: e.toString(),
          );
          remainingFailures.add(updatedFailure);
        }
      }

      // Update final status
      final finalStatus = remainingFailures.isEmpty
          ? MigrationStatus.completed
          : MigrationStatus.completed;

      _progress = _progress.copyWith(
        status: finalStatus,
        failures: remainingFailures,
      );
      _emitProgress();

      safePrint(
          'Retry completed: $retriedCount succeeded, ${remainingFailures.length} still failed');

      return _progress;
    } catch (e) {
      safePrint('Retry failed with error: $e');

      _progress = _progress.copyWith(
        status: MigrationStatus.failed,
        error: e.toString(),
      );
      _emitProgress();

      return _progress;
    }
  }

  /// Reset migration state
  /// Clears all migration progress and failures
  void resetMigration() {
    _progress = MigrationProgress(
      totalDocuments: 0,
      migratedDocuments: 0,
      failedDocuments: 0,
      status: MigrationStatus.notStarted,
    );
    _isCancelled = false;
    _emitProgress();
  }

  // Private methods

  /// Migrate a single document to cloud storage
  Future<void> _migrateDocument(Document document) async {
    try {
      // Upload document metadata to DynamoDB
      await _documentSyncManager.uploadDocument(document);

      // Upload file attachments to S3
      for (final filePath in document.filePaths) {
        await _fileSyncManager.uploadFile(filePath, document.id.toString());
      }

      // Update local document sync state to synced
      final updatedDocument =
          document.copyWith(syncState: SyncState.synced.toJson());
      await _databaseService.updateDocument(updatedDocument);

      safePrint('Successfully migrated document ${document.id}');
    } catch (e) {
      safePrint('Error migrating document ${document.id}: $e');
      rethrow;
    }
  }

  /// Verify that all documents were successfully migrated
  Future<void> _verifyMigration(
    List<Document> localDocuments,
    List<MigrationFailure> failures,
  ) async {
    try {
      safePrint('Verifying migration...');

      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('Could not get current user for verification');
      }

      // Fetch all documents from remote
      final remoteDocuments =
          await _documentSyncManager.fetchAllDocuments(user.id);

      // Check that all successfully migrated documents exist in remote
      final failedDocumentIds = failures.map((f) => f.documentId).toSet();
      final expectedRemoteCount = localDocuments.length - failures.length;

      if (remoteDocuments.length < expectedRemoteCount) {
        safePrint(
            'Warning: Expected $expectedRemoteCount documents in remote, but found ${remoteDocuments.length}');
      }

      // Verify each local document (except failed ones) exists in remote
      for (final localDoc in localDocuments) {
        if (failedDocumentIds.contains(localDoc.id.toString())) {
          continue;
        }

        final remoteDoc = remoteDocuments.firstWhere(
          (doc) => doc.id == localDoc.id,
          orElse: () => Document(
            userId: 'unknown',
            title: '',
            category: '',
            filePaths: [],
            createdAt: amplify_core.TemporalDateTime.now(),
            lastModified: amplify_core.TemporalDateTime.now(),
            version: 0,
            syncState: SyncState.notSynced.toJson(),
          ),
        );

        if (remoteDoc.title.isEmpty) {
          safePrint(
              'Warning: Document ${localDoc.id} not found in remote storage');
        }
      }

      safePrint('Migration verification completed');
    } catch (e) {
      safePrint('Error during migration verification: $e');
      // Don't throw - verification is informational
    }
  }

  /// Emit progress update to stream
  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(_progress);
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _progressController.close();
    // SimpleFileSyncManager doesn't need disposal
  }
}
