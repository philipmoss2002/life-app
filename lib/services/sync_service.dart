import 'dart:async';
import '../models/sync_result.dart';
import '../models/sync_state.dart';
import '../repositories/document_repository.dart';
import 'authentication_service.dart';
import 'connectivity_service.dart';
import 'file_service.dart';
import 'document_sync_service.dart';
import 'file_attachment_sync_service.dart';
import 'log_service.dart' as log_svc;

/// Custom exception for sync operations
class SyncException implements Exception {
  final String message;
  SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}

/// Status of sync operation
enum SyncStatus {
  idle,
  syncing,
  completed,
  error,
}

/// Service for coordinating document synchronization between local and remote storage
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _documentRepository = DocumentRepository();
  final _fileService = FileService();
  final _authService = AuthenticationService();
  final _connectivityService = ConnectivityService();
  final _documentSyncService = DocumentSyncService();
  final _fileAttachmentSyncService = FileAttachmentSyncService();
  final _logService = log_svc.LogService();

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  bool _isSyncing = false;
  Timer? _debounceTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Stream of sync status changes
  Stream<SyncStatus> get syncStatusStream => _syncStatusController.stream;

  /// Check if sync is currently in progress
  bool get isSyncing => _isSyncing;

  /// Initialize sync service and connectivity monitoring
  Future<void> initialize() async {
    _logService.log(
      'Initializing sync service',
      level: log_svc.LogLevel.info,
    );

    // Initialize connectivity service
    await _connectivityService.initialize();

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivityService.connectivityStream.listen((isOnline) {
      if (isOnline) {
        syncOnNetworkRestored();
      }
    });

    _logService.log(
      'Sync service initialized',
      level: log_svc.LogLevel.info,
    );
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _debounceTimer?.cancel();
  }

  /// Perform full sync operation (upload pending, download new)
  Future<SyncResult> performSync() async {
    if (_isSyncing) {
      _logService.log(
        'Sync already in progress, skipping',
        level: log_svc.LogLevel.warning,
      );
      throw SyncException('Sync already in progress');
    }

    // Check network connectivity
    if (!_connectivityService.isOnline) {
      _logService.log(
        'No network connectivity, skipping sync',
        level: log_svc.LogLevel.warning,
      );
      throw SyncException('No network connectivity');
    }

    _isSyncing = true;
    _syncStatusController.add(SyncStatus.syncing);

    final startTime = DateTime.now();
    int uploadedCount = 0;
    int downloadedCount = 0;
    final errors = <String>[];

    _logService.log('Starting full sync operation',
        level: log_svc.LogLevel.info);

    try {
      // Check authentication
      if (!await _authService.isAuthenticated()) {
        throw SyncException('User is not authenticated');
      }

      final identityPoolId = await _authService.getIdentityPoolId();

      // Phase 1: Pull remote document changes
      try {
        _logService.log(
          'Phase 1: Pulling remote document changes',
          level: log_svc.LogLevel.info,
        );
        await _documentSyncService.pullRemoteDocuments();
      } catch (e) {
        errors.add('Pull remote documents failed: $e');
        _logService.log(
          'Pull remote documents failed: $e',
          level: log_svc.LogLevel.error,
        );
      }

      // Phase 2: Upload pending documents
      try {
        final pendingDocs =
            await _documentRepository.getDocumentsNeedingUpload();
        _logService.log(
          'Found ${pendingDocs.length} documents needing upload',
          level: log_svc.LogLevel.info,
        );

        for (final doc in pendingDocs) {
          try {
            // Push document metadata to DocumentDB
            await _documentSyncService.pushDocumentToRemote(doc);

            // Upload files to S3
            await uploadDocumentFiles(doc.syncId, identityPoolId);
            uploadedCount++;
          } catch (e) {
            errors.add('Upload failed for ${doc.title}: $e');
            _logService.log(
              'Failed to upload document ${doc.syncId}: $e',
              level: log_svc.LogLevel.error,
            );
          }
        }
      } catch (e) {
        errors.add('Upload phase failed: $e');
        _logService.log('Upload phase failed: $e',
            level: log_svc.LogLevel.error);
      }

      // Phase 3: Download missing files
      try {
        final downloadDocs =
            await _documentRepository.getDocumentsNeedingDownload();
        _logService.log(
          'Found ${downloadDocs.length} documents needing download',
          level: log_svc.LogLevel.info,
        );

        for (final doc in downloadDocs) {
          try {
            await downloadDocumentFiles(doc.syncId, identityPoolId);
            downloadedCount++;
          } catch (e) {
            errors.add('Download failed for ${doc.title}: $e');
            _logService.log(
              'Failed to download document ${doc.syncId}: $e',
              level: log_svc.LogLevel.error,
            );
          }
        }
      } catch (e) {
        errors.add('Download phase failed: $e');
        _logService.log('Download phase failed: $e',
            level: log_svc.LogLevel.error);
      }

      final duration = DateTime.now().difference(startTime);
      final result = SyncResult(
        uploadedCount: uploadedCount,
        downloadedCount: downloadedCount,
        failedCount: errors.length,
        errors: errors,
        duration: duration,
      );

      _logService.log(
        'Sync completed: ${result.uploadedCount} uploaded, ${result.downloadedCount} downloaded, ${result.failedCount} failed in ${result.duration.inSeconds}s',
        level: log_svc.LogLevel.info,
      );

      _syncStatusController.add(SyncStatus.completed);
      return result;
    } catch (e) {
      _logService.log('Sync failed: $e', level: log_svc.LogLevel.error);
      _syncStatusController.add(SyncStatus.error);
      rethrow;
    } finally {
      _isSyncing = false;
      _syncStatusController.add(SyncStatus.idle);
    }
  }

  /// Sync a specific document
  Future<void> syncDocument(String syncId) async {
    _logService.log('Syncing document: $syncId', level: log_svc.LogLevel.info);

    try {
      if (!await _authService.isAuthenticated()) {
        throw SyncException('User is not authenticated');
      }

      final identityPoolId = await _authService.getIdentityPoolId();
      final doc = await _documentRepository.getDocument(syncId);

      if (doc == null) {
        throw SyncException('Document not found: $syncId');
      }

      // Determine what needs to be done
      if (doc.syncState == SyncState.pendingUpload ||
          doc.syncState == SyncState.error) {
        // Push document metadata to DocumentDB
        await _documentSyncService.pushDocumentToRemote(doc);

        // Upload files to S3
        await uploadDocumentFiles(syncId, identityPoolId);
      } else if (doc.syncState == SyncState.pendingDownload) {
        // Download files from S3
        await downloadDocumentFiles(syncId, identityPoolId);
      }

      _logService.log(
        'Document synced successfully: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Failed to sync document $syncId: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Upload files for a specific document
  Future<void> uploadDocumentFiles(String syncId, String identityPoolId) async {
    _logService.log(
      'Uploading files for document: $syncId',
      level: log_svc.LogLevel.info,
    );

    try {
      final doc = await _documentRepository.getDocument(syncId);
      if (doc == null) {
        throw SyncException('Document not found: $syncId');
      }

      // Get user ID for FileAttachment records
      final userId = await _authService.getUserId();

      // Update state to uploading
      await _documentRepository.updateSyncState(syncId, SyncState.uploading);

      // Upload each file that has a local path but no S3 key
      for (final file in doc.files) {
        if (file.localPath != null && file.s3Key == null) {
          try {
            _logService.log(
              'Uploading file: ${file.fileName}',
              level: log_svc.LogLevel.info,
            );

            final s3Key = await _fileService.uploadFile(
              localFilePath: file.localPath!,
              syncId: syncId,
              identityPoolId: identityPoolId,
            );

            // Update S3 key in local database
            await _documentRepository.updateFileS3Key(
              syncId: syncId,
              fileName: file.fileName,
              s3Key: s3Key,
            );

            // Create FileAttachment record in DynamoDB
            // Generate a unique syncId for the file attachment
            final fileAttachmentSyncId = '${syncId}_${file.fileName}';

            await _fileAttachmentSyncService.createRemoteFileAttachment(
              syncId: fileAttachmentSyncId,
              documentSyncId: syncId,
              userId: userId,
              fileName: file.fileName,
              label: file.label,
              fileSize: file.fileSize ?? 0,
              s3Key: s3Key,
              filePath: s3Key,
              addedAt: file.addedAt,
              contentType: null, // Not tracked in local model
              checksum: null, // Not tracked in local model
              syncState: 'synced',
            );

            _logService.log(
              'File uploaded successfully: ${file.fileName}',
              level: log_svc.LogLevel.info,
            );
          } catch (e) {
            _logService.log(
              'Failed to upload file ${file.fileName}: $e',
              level: log_svc.LogLevel.error,
            );
            // Mark as error and rethrow
            await _documentRepository.updateSyncState(syncId, SyncState.error);
            rethrow;
          }
        }
      }

      // Update state to synced
      await _documentRepository.updateSyncState(syncId, SyncState.synced);

      _logService.log(
        'All files uploaded for document: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Upload failed for document $syncId: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Download files for a specific document
  Future<void> downloadDocumentFiles(
      String syncId, String identityPoolId) async {
    _logService.log(
      'Downloading files for document: $syncId',
      level: log_svc.LogLevel.info,
    );

    try {
      final doc = await _documentRepository.getDocument(syncId);
      if (doc == null) {
        throw SyncException('Document not found: $syncId');
      }

      // Update state to downloading
      await _documentRepository.updateSyncState(syncId, SyncState.downloading);

      // Download each file that has an S3 key but no local path
      for (final file in doc.files) {
        if (file.s3Key != null && file.localPath == null) {
          try {
            _logService.log(
              'Downloading file: ${file.fileName}',
              level: log_svc.LogLevel.info,
            );

            final localPath = await _fileService.downloadFile(
              s3Key: file.s3Key!,
              syncId: syncId,
              identityPoolId: identityPoolId,
            );

            // Update local path in database
            await _documentRepository.updateFileLocalPath(
              syncId: syncId,
              fileName: file.fileName,
              localPath: localPath,
            );

            _logService.log(
              'File downloaded successfully: ${file.fileName}',
              level: log_svc.LogLevel.info,
            );
          } catch (e) {
            _logService.log(
              'Failed to download file ${file.fileName}: $e',
              level: log_svc.LogLevel.error,
            );
            // Mark as error and rethrow
            await _documentRepository.updateSyncState(syncId, SyncState.error);
            rethrow;
          }
        }
      }

      // Update state to synced
      await _documentRepository.updateSyncState(syncId, SyncState.synced);

      _logService.log(
        'All files downloaded for document: $syncId',
        level: log_svc.LogLevel.info,
      );
    } catch (e) {
      _logService.log(
        'Download failed for document $syncId: $e',
        level: log_svc.LogLevel.error,
      );
      rethrow;
    }
  }

  /// Trigger sync with debouncing to prevent excessive sync operations
  void triggerSync({Duration debounceDelay = const Duration(seconds: 2)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDelay, () {
      performSync().catchError((e) {
        _logService.log(
          'Triggered sync failed: $e',
          level: log_svc.LogLevel.error,
        );
        // Return a failed sync result
        return SyncResult(
          uploadedCount: 0,
          downloadedCount: 0,
          failedCount: 1,
          errors: [e.toString()],
          duration: Duration.zero,
        );
      });
    });
  }

  /// Trigger sync on app launch (after authentication)
  Future<void> syncOnAppLaunch() async {
    _logService.log('Triggering sync on app launch',
        level: log_svc.LogLevel.info);
    try {
      if (await _authService.isAuthenticated()) {
        await performSync();
      } else {
        _logService.log(
          'Skipping sync on app launch: user not authenticated',
          level: log_svc.LogLevel.warning,
        );
      }
    } catch (e) {
      _logService.log(
        'Sync on app launch failed: $e',
        level: log_svc.LogLevel.error,
      );
    }
  }

  /// Trigger sync on document creation/modification
  void syncOnDocumentChange(String syncId) {
    _logService.log(
      'Triggering sync for document change: $syncId',
      level: log_svc.LogLevel.info,
    );
    triggerSync();
  }

  /// Trigger sync on network connectivity restoration
  void syncOnNetworkRestored() {
    _logService.log(
      'Triggering sync on network restoration',
      level: log_svc.LogLevel.info,
    );
    triggerSync(debounceDelay: const Duration(seconds: 5));
  }

  /// Verify sync state consistency (optional, for debugging)
  ///
  /// Checks for inconsistencies between document metadata and file references.
  /// Logs warnings but doesn't fail - used for monitoring and debugging.
  Future<void> verifySyncConsistency() async {
    try {
      _logService.log(
        'Verifying sync state consistency',
        level: log_svc.LogLevel.info,
      );

      final allDocs = await _documentRepository.getAllDocuments();
      int inconsistencyCount = 0;

      for (final doc in allDocs) {
        // Check for files with S3 keys but no local paths
        final missingLocalPaths = doc.files
            .where((f) => f.s3Key != null && f.localPath == null)
            .toList();

        if (missingLocalPaths.isNotEmpty && doc.syncState == SyncState.synced) {
          inconsistencyCount++;
          _logService.log(
            'Inconsistency: Document "${doc.title}" (${doc.syncId}) has ${missingLocalPaths.length} file(s) with S3 keys but no local paths',
            level: log_svc.LogLevel.warning,
          );
        }

        // Check for files with local paths but no S3 keys
        final missingS3Keys = doc.files
            .where((f) => f.localPath != null && f.s3Key == null)
            .toList();

        if (missingS3Keys.isNotEmpty && doc.syncState == SyncState.synced) {
          inconsistencyCount++;
          _logService.log(
            'Inconsistency: Document "${doc.title}" (${doc.syncId}) has ${missingS3Keys.length} file(s) with local paths but no S3 keys',
            level: log_svc.LogLevel.warning,
          );
        }

        // Check for documents marked as synced with no files
        if (doc.files.isEmpty && doc.syncState == SyncState.synced) {
          // This is actually fine - documents can have no files
          continue;
        }
      }

      if (inconsistencyCount == 0) {
        _logService.log(
          'Sync consistency verification passed: no inconsistencies found',
          level: log_svc.LogLevel.info,
        );
      } else {
        _logService.log(
          'Sync consistency verification found $inconsistencyCount inconsistencies',
          level: log_svc.LogLevel.warning,
        );
      }
    } catch (e) {
      _logService.log(
        'Failed to verify sync consistency: $e',
        level: log_svc.LogLevel.error,
      );
    }
  }
}
