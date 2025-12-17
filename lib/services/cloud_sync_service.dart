import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/Document.dart';
import '../models/sync_event.dart';
import '../models/sync_state.dart';
import 'document_sync_manager.dart';
import 'simple_file_sync_manager.dart';
import 'authentication_service.dart';
import 'subscription_service.dart' as sub;
import 'database_service.dart';
import 'analytics_service.dart';
import 'offline_sync_queue_service.dart';
import 'log_service.dart' as app_log;

/// Enum representing conflict resolution strategies
enum ConflictResolution {
  keepLocal,
  keepRemote,
  merge,
}

/// Model representing sync status
class SyncStatus {
  final bool isSyncing;
  final int pendingChanges;
  final DateTime? lastSyncTime;
  final String? error;

  SyncStatus({
    required this.isSyncing,
    required this.pendingChanges,
    this.lastSyncTime,
    this.error,
  });
}

/// Model representing a queued sync operation
class SyncOperation {
  final String id;
  final String documentId;
  final SyncOperationType type;
  final DateTime queuedAt;
  final int retryCount;
  final Document? document;

  SyncOperation({
    required this.id,
    required this.documentId,
    required this.type,
    DateTime? queuedAt,
    this.retryCount = 0,
    this.document,
  }) : queuedAt = queuedAt ?? DateTime.now();

  SyncOperation copyWith({
    String? id,
    String? documentId,
    SyncOperationType? type,
    DateTime? queuedAt,
    int? retryCount,
    Document? document,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      type: type ?? this.type,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      document: document ?? this.document,
    );
  }
}

enum SyncOperationType {
  upload,
  update,
  delete,
}

/// Core cloud synchronization service
/// Orchestrates synchronization between local and remote storage
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  // Dependencies
  final DocumentSyncManager _documentSyncManager = DocumentSyncManager();
  final SimpleFileSyncManager _fileSyncManager = SimpleFileSyncManager();
  final AuthenticationService _authService = AuthenticationService();
  final sub.SubscriptionService _subscriptionService =
      sub.SubscriptionService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final Connectivity _connectivity = Connectivity();
  final AnalyticsService _analyticsService = AnalyticsService();
  final OfflineSyncQueueService _queueService = OfflineSyncQueueService();
  final app_log.LogService _logService = app_log.LogService();

  // State
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _hasUploadedInCurrentSync = false;
  String? _lastSyncHash; // Hash of documents to detect changes

  // Debug flag to bypass subscription check (for testing only)
  static bool _bypassSubscriptionCheck = false;
  Timer? _periodicSyncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Sync queue
  final List<SyncOperation> _syncQueue = [];

  // Event streaming
  final StreamController<SyncEvent> _syncEventController =
      StreamController<SyncEvent>.broadcast();

  /// Stream of sync events
  Stream<SyncEvent> get syncEvents => _syncEventController.stream;

  /// Initialize the cloud sync service
  Future<void> initialize() async {
    if (_isInitialized) {
      _logService.log('CloudSyncService already initialized',
          level: app_log.LogLevel.info);
      return;
    }

    try {
      // Verify Amplify is configured
      if (!Amplify.isConfigured) {
        throw Exception(
            'Amplify is not configured. Please run amplify configure.');
      }

      // Check authentication
      final isAuthenticated = await _authService.isAuthenticated();
      if (!isAuthenticated) {
        _logInfo('User not authenticated, skipping sync initialization');
        return;
      }

      // Check subscription status (unless bypassed for testing)
      if (!_bypassSubscriptionCheck) {
        _logInfo('Checking subscription status for sync initialization...');
        final subscriptionStatus =
            await _subscriptionService.getSubscriptionStatus();
        _logInfo('Subscription status: ${subscriptionStatus.name}');
        if (subscriptionStatus != sub.SubscriptionStatus.active) {
          _logInfo(
              'No active subscription (${subscriptionStatus.name}), skipping sync initialization');
          return;
        }
        _logInfo(
            'Active subscription confirmed, proceeding with sync initialization');
      } else {
        _logWarning('⚠️ BYPASSING subscription check for testing purposes');
      }

      // Set up network connectivity monitoring
      _setupConnectivityMonitoring();

      // Initialize offline sync queue service
      await _queueService.initialize();

      _isInitialized = true;
      _logInfo('CloudSyncService initialized successfully');

      _emitEvent(_createSyncEvent(
        SyncEventType.syncStarted,
        message: 'Sync service initialized',
      ));
    } catch (e) {
      _isInitialized = false;
      final errorMessage = e.toString();
      _logError('Error initializing CloudSyncService: $errorMessage');

      // Provide more specific error messages for common issues
      if (errorMessage.contains('Amplify is not configured')) {
        _logError(
            'Please ensure Amplify is properly configured before initializing sync');
      } else if (errorMessage.contains('network') ||
          errorMessage.contains('connection')) {
        _logError('Network connectivity issue during initialization');
      }

      rethrow;
    }
  }

  /// Start automatic synchronization
  Future<void> startSync() async {
    if (!_isInitialized) {
      throw Exception(
          'CloudSyncService not initialized. Call initialize() first.');
    }

    if (_isSyncing) {
      _logInfo('Sync already running');
      return;
    }

    try {
      _isSyncing = true;
      _logInfo('Starting cloud sync');

      // Perform initial sync
      await syncNow();

      // Start periodic sync (every 5 minutes to reduce duplication)
      _periodicSyncTimer?.cancel();
      _periodicSyncTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _performPeriodicSync(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.syncStarted.value,
        entityType: 'sync',
        entityId: 'auto',
        message: 'Automatic sync started',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      _isSyncing = false;
      _logError('Error starting sync: $e');
      rethrow;
    }
  }

  /// Stop automatic synchronization
  Future<void> stopSync() async {
    _logInfo('Stopping cloud sync');

    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
    _isSyncing = false;

    _emitEvent(_createSyncEvent(
      SyncEventType.syncCompleted,
      message: 'Automatic sync stopped',
    ));
  }

  /// Manually trigger synchronization
  Future<void> syncNow() async {
    if (!_isInitialized) {
      throw Exception('CloudSyncService not initialized');
    }

    // Check network connectivity and settings
    final connectivityResult = await _connectivity.checkConnectivity();
    if (!await _shouldSync(connectivityResult)) {
      _logInfo('Sync conditions not met, skipping sync');
      return;
    }

    try {
      _logInfo('Starting manual sync');
      _hasUploadedInCurrentSync = false;

      // Process sync queue first
      await _processSyncQueue();

      // Only sync from remote if we didn't upload documents in this sync cycle
      // This prevents downloading documents that were just uploaded
      if (!_hasUploadedInCurrentSync) {
        _logInfo('No uploads in this sync, syncing from remote');
        await _syncFromRemote();
      } else {
        _logInfo(
            'Documents were uploaded in this sync, skipping sync from remote to avoid duplicates');
      }

      _lastSyncTime = DateTime.now();
      _lastSyncHash = await _calculateDocumentsHash();

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.syncCompleted.value,
        entityType: 'sync',
        entityId: 'global',
        message: 'Sync completed successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      _logError('Error during sync: $e');
      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.syncFailed.value,
        entityType: 'sync',
        entityId: 'global',
        message: 'Sync failed: $e',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
      rethrow;
    }
  }

  /// Get current sync status
  Future<SyncStatus> getSyncStatus() async {
    return SyncStatus(
      isSyncing: _isSyncing,
      pendingChanges: _syncQueue.length,
      lastSyncTime: _lastSyncTime,
    );
  }

  /// Queue a document for synchronization
  Future<void> queueDocumentSync(
      Document document, SyncOperationType type) async {
    final operation = SyncOperation(
      id: '${document.id}_${DateTime.now().millisecondsSinceEpoch}',
      documentId: document.id.toString(),
      type: type,
      document: document,
    );

    _syncQueue.add(operation);
    _logInfo(
        'Queued sync operation: ${operation.type} for document ${document.id}');

    // Update document sync state to pending
    try {
      await _updateLocalDocumentSyncState(document.id, SyncState.pending);
    } catch (e) {
      // Ignore database errors in test environment
      _logWarning('Could not update local sync state: $e');
    }

    // Try to sync immediately if online and conditions are met
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (await _shouldSync(connectivityResult)) {
        await _processSyncQueue();
      }
    } catch (e) {
      // Ignore connectivity errors in test environment
      _logWarning('Could not check connectivity: $e');
    }
  }

  /// Resolve a conflict
  Future<void> resolveConflict(
    String documentId,
    ConflictResolution resolution,
  ) async {
    // This will be implemented in the conflict resolution service
    // For now, just log the resolution
    _logInfo(
        'Resolving conflict for document $documentId with strategy: $resolution');
  }

  // Private methods

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
    );
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) async {
    if (await _shouldSync(results)) {
      _logInfo(
          'Network connectivity restored and sync conditions met, processing sync queue');
      _processSyncQueue();
    } else {
      _logInfo('Network connectivity changed but sync conditions not met');
    }
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
  }

  /// Check if sync should proceed based on connectivity and settings
  Future<bool> _shouldSync(List<ConnectivityResult> results) async {
    // Check if sync is paused
    final prefs = await SharedPreferences.getInstance();
    final syncPaused = prefs.getBool('sync_paused') ?? false;
    if (syncPaused) {
      _logInfo('Sync is paused by user');
      return false;
    }

    // Check if connected
    if (!_isConnected(results)) {
      _logInfo('No network connectivity');
      return false;
    }

    // Check Wi-Fi only setting
    final wifiOnly = prefs.getBool('sync_wifi_only') ?? false;
    if (wifiOnly) {
      final hasWifi = results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
      if (!hasWifi) {
        _logInfo('Wi-Fi only mode enabled, but not on Wi-Fi');
        return false;
      }
    }

    return true;
  }

  Future<void> _performPeriodicSync() async {
    if (!_isSyncing) return;

    try {
      // Check if there are any changes since last sync
      final currentHash = await _calculateDocumentsHash();
      if (_lastSyncHash != null && _lastSyncHash == currentHash) {
        _logInfo('No changes detected, skipping periodic sync');
        return;
      }

      _logInfo('Changes detected, performing periodic sync');
      await syncNow();
      _lastSyncHash = currentHash;
    } catch (e) {
      _logError('Error during periodic sync: $e');
    }
  }

  Future<void> _processSyncQueue() async {
    if (_syncQueue.isEmpty) {
      return;
    }

    _logInfo('Processing sync queue: ${_syncQueue.length} operations');

    final operations = List<SyncOperation>.from(_syncQueue);
    _syncQueue.clear();

    for (final operation in operations) {
      try {
        await _processSyncOperation(operation);
      } catch (e) {
        _logError('Error processing sync operation: $e');

        // Retry logic with exponential backoff
        if (operation.retryCount < 5) {
          final updatedOperation = operation.copyWith(
            retryCount: operation.retryCount + 1,
          );
          _syncQueue.add(updatedOperation);

          // Wait before retrying (exponential backoff)
          await Future.delayed(
            Duration(seconds: 1 << operation.retryCount),
          );
        } else {
          // Max retries reached, mark as error
          await _updateLocalDocumentSyncState(
              operation.documentId, SyncState.error);

          _emitEvent(SyncEvent(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            eventType: SyncEventType.syncFailed.value,
            entityType: 'document',
            entityId: operation.documentId,
            message: 'Max retries reached for sync operation',
            timestamp: amplify_core.TemporalDateTime.now(),
          ));
        }
      }
    }
  }

  Future<void> _processSyncOperation(SyncOperation operation) async {
    if (operation.document == null) {
      throw Exception('Document is null for sync operation');
    }

    final document = operation.document!;

    switch (operation.type) {
      case SyncOperationType.upload:
        await _uploadDocument(document);
        break;
      case SyncOperationType.update:
        await _updateDocument(document);
        break;
      case SyncOperationType.delete:
        await _deleteDocument(document);
        break;
    }
  }

  Future<void> _uploadDocument(Document document) async {
    final startTime = DateTime.now();
    try {
      // Mark that we're uploading in this sync cycle
      _hasUploadedInCurrentSync = true;

      _logInfo('🔄 Starting upload for document: ${document.id}');
      _logInfo('📁 File paths: ${document.filePaths}');

      // Update sync state to syncing
      await _updateLocalDocumentSyncState(document.id, SyncState.syncing);

      // Upload file attachments first and get S3 keys
      Document documentToUpload = document;
      if (document.filePaths.isNotEmpty) {
        _logInfo('📤 Uploading ${document.filePaths.length} files...');
        final fileStartTime = DateTime.now();

        try {
          final uploadResults = await _fileSyncManager.uploadFilesParallel(
            document.filePaths,
            document.id.toString(),
          );
          _logInfo('✅ Files uploaded successfully: ${uploadResults.keys}');

          final fileLatency =
              DateTime.now().difference(fileStartTime).inMilliseconds;

          // Update document with S3 keys instead of local paths
          final s3Keys = uploadResults.values.toList();
          _logInfo('🔑 S3 keys: $s3Keys');
          documentToUpload = document.copyWith(filePaths: s3Keys);
          await _databaseService.updateDocument(documentToUpload);
          _logInfo('✅ Document updated with S3 keys');

          // Track file upload analytics
          await _analyticsService.trackSyncEvent(
            type: AnalyticsSyncEventType.fileUpload,
            success: true,
            latencyMs: fileLatency,
            documentId: document.id.toString(),
          );
        } catch (e) {
          _logError('❌ File upload failed: $e');
          rethrow;
        }
      }

      // Upload document metadata with S3 keys (not local paths)
      _logInfo('📋 Uploading document metadata...');
      _logInfo('📄 Document title: ${documentToUpload.title}');
      _logInfo('👤 Document user ID: ${documentToUpload.userId}');
      _logInfo('📁 Document file paths: ${documentToUpload.filePaths}');
      _logInfo('🔢 Document version: ${documentToUpload.version}');

      try {
        final uploadedDocument =
            await _documentSyncManager.uploadDocument(documentToUpload);
        _logInfo('✅ Document metadata uploaded successfully to DynamoDB');

        // If DynamoDB generated a new ID, update the local document
        if (uploadedDocument.id != document.id) {
          _logInfo(
              '🔄 Updating local document with DynamoDB ID: ${uploadedDocument.id}');
          _logInfo('📝 Original local ID was: ${document.id}');

          // Update the local document with the new ID and other DynamoDB fields
          await _databaseService.updateDocument(uploadedDocument);
          _logInfo('✅ Local document updated with DynamoDB ID');

          // Update the sync hash since we changed the document
          _lastSyncHash = await _calculateDocumentsHash();
        }
      } catch (e, stackTrace) {
        _logError('❌ Document metadata upload failed: $e');
        _logError('📍 Error type: ${e.runtimeType}');
        _logError('📍 Full error details: ${e.toString()}');
        _logError('📍 Stack trace: $stackTrace');

        // Check for specific error types
        if (e.toString().contains('API plugin has not been added')) {
          _logError('🔧 SOLUTION: API plugin is not configured properly');
        } else if (e.toString().contains('UnauthorizedException')) {
          _logError(
              '🔧 SOLUTION: Authentication issue - user may not be properly signed in');
        } else if (e.toString().contains('ValidationException')) {
          _logError(
              '🔧 SOLUTION: Data validation issue - check document fields');
        }

        rethrow;
      }

      // Update sync state to synced (use the original document ID for local state tracking)
      await _updateLocalDocumentSyncState(document.id, SyncState.synced);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document upload analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpload,
        success: true,
        latencyMs: latency,
        documentId: document.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.id.toString(),
        message: 'Document uploaded successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      await _updateLocalDocumentSyncState(document.id, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed upload analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpload,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.id.toString(),
      );

      rethrow;
    }
  }

  Future<void> _updateDocument(Document document) async {
    final startTime = DateTime.now();
    try {
      // Update sync state to syncing
      await _updateLocalDocumentSyncState(document.id, SyncState.syncing);

      // Update document metadata
      await _documentSyncManager.updateDocument(document);

      // Update sync state to synced
      await _updateLocalDocumentSyncState(document.id, SyncState.synced);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: true,
        latencyMs: latency,
        documentId: document.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.id.toString(),
        message: 'Document updated successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } on VersionConflictException catch (e) {
      // Conflict detected
      await _updateLocalDocumentSyncState(document.id, SyncState.conflict);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.message,
        documentId: document.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.conflictDetected.value,
        entityType: 'document',
        entityId: document.id.toString(),
        message: 'Conflict detected: ${e.message}',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));

      rethrow;
    } catch (e) {
      await _updateLocalDocumentSyncState(document.id, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.id.toString(),
      );

      rethrow;
    }
  }

  Future<void> _deleteDocument(Document document) async {
    final startTime = DateTime.now();
    try {
      // Update sync state to syncing
      await _updateLocalDocumentSyncState(document.id, SyncState.syncing);

      // Delete document from remote
      await _documentSyncManager.deleteDocument(document.id.toString());

      // Delete files from remote (filePaths now contain S3 keys)
      for (final s3Key in document.filePaths) {
        final fileStartTime = DateTime.now();
        try {
          await _fileSyncManager.deleteFile(s3Key);
          final fileLatency =
              DateTime.now().difference(fileStartTime).inMilliseconds;

          // Track file delete analytics
          await _analyticsService.trackSyncEvent(
            type: AnalyticsSyncEventType.fileDelete,
            success: true,
            latencyMs: fileLatency,
            documentId: document.id.toString(),
          );
        } catch (e) {
          _logError('Failed to delete file $s3Key: $e');
          // Continue with other files instead of failing completely
        }
      }

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document delete analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentDelete,
        success: true,
        latencyMs: latency,
        documentId: document.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.id.toString(),
        message: 'Document deleted successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      await _updateLocalDocumentSyncState(document.id, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed delete analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentDelete,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.id.toString(),
      );

      rethrow;
    }
  }

  Future<void> _syncFromRemote() async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Fetch all documents from remote
      final remoteDocuments =
          await _documentSyncManager.fetchAllDocuments(user.id);

      // Get local documents
      final localDocuments = await _databaseService.getAllDocuments();

      // Sync remote documents to local
      for (final remoteDoc in remoteDocuments) {
        // Try to find matching local document by ID first
        Document? localDoc = localDocuments.firstWhere(
          (doc) => doc.id.toString() == remoteDoc.id.toString(),
          orElse: () => Document(
            userId: 'unknown',
            title: '',
            category: '',
            filePaths: [],
            createdAt: amplify_core.TemporalDateTime.now(),
            lastModified: amplify_core.TemporalDateTime.now(),
            version: 0,
            syncState: SyncState.pending.toJson(),
          ),
        );

        // If not found by ID, try to find by title, category, and creation time (potential duplicate)
        if (localDoc.title.isEmpty) {
          localDoc = localDocuments.firstWhere(
            (doc) =>
                doc.title == remoteDoc.title &&
                doc.category == remoteDoc.category &&
                doc.createdAt.format() == remoteDoc.createdAt.format() &&
                doc.userId == remoteDoc.userId,
            orElse: () => Document(
              userId: 'unknown',
              title: '',
              category: '',
              filePaths: [],
              createdAt: amplify_core.TemporalDateTime.now(),
              lastModified: amplify_core.TemporalDateTime.now(),
              version: 0,
              syncState: SyncState.pending.toJson(),
            ),
          );

          // If we found a potential duplicate, update the local document with the remote ID
          if (localDoc.title.isNotEmpty) {
            _logInfo(
                '🔍 Found potential duplicate document: ${localDoc.title}');
            _logInfo(
                '🔄 Replacing local document ID ${localDoc.id} with remote ID ${remoteDoc.id}');

            // Delete the old local document
            await _databaseService.deleteDocument(int.parse(localDoc.id));

            // Create the remote document locally
            await _databaseService.createDocument(remoteDoc);
            _logInfo('✅ Local duplicate replaced with remote document');
            continue; // Skip further processing for this document
          }
        }

        if (localDoc.title.isEmpty) {
          // Document doesn't exist locally, download it
          _logInfo('📥 Downloading new document: ${remoteDoc.title}');
          await _downloadDocument(remoteDoc);
        } else if (remoteDoc.version > localDoc.version) {
          // Remote version is newer, update local
          _logInfo('🔄 Remote version newer for: ${remoteDoc.title}');
          await _downloadDocument(remoteDoc);
        } else if (localDoc.version > remoteDoc.version) {
          // Local version is newer, upload to remote
          _logInfo('⬆️ Local version newer for: ${localDoc.title}');
          await queueDocumentSync(localDoc, SyncOperationType.update);
        } else {
          // Versions are the same, no action needed
          _logInfo('✅ Document in sync: ${localDoc.title}');
        }
      }
    } catch (e) {
      _logError('Error syncing from remote: $e');
      rethrow;
    }
  }

  Future<void> _downloadDocument(Document remoteDoc) async {
    final startTime = DateTime.now();
    try {
      // Download file attachments (filePaths now contain S3 keys)
      for (final s3Key in remoteDoc.filePaths) {
        final fileStartTime = DateTime.now();
        try {
          await _fileSyncManager.downloadFile(s3Key, remoteDoc.id.toString());
          final fileLatency =
              DateTime.now().difference(fileStartTime).inMilliseconds;

          // Track file download analytics
          await _analyticsService.trackSyncEvent(
            type: AnalyticsSyncEventType.fileDownload,
            success: true,
            latencyMs: fileLatency,
            documentId: remoteDoc.id.toString(),
          );
        } catch (e) {
          _logError('Failed to download file $s3Key: $e');
          // Continue with other files instead of failing completely
        }
      }

      // Update or insert document in local database
      final existingDoc = await _databaseService.getAllDocuments();
      final docExists = existingDoc.any((doc) => doc.id == remoteDoc.id);

      if (docExists) {
        await _databaseService.updateDocument(remoteDoc);
      } else {
        await _databaseService.createDocument(remoteDoc);
      }

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document download analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentDownload,
        success: true,
        latencyMs: latency,
        documentId: remoteDoc.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.documentDownloaded.value,
        entityType: 'document',
        entityId: remoteDoc.id.toString(),
        message: 'Document downloaded successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      _logError('Error downloading document: $e');

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed download analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentDownload,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: remoteDoc.id.toString(),
      );

      rethrow;
    }
  }

  Future<void> _updateLocalDocumentSyncState(
      String documentId, SyncState state) async {
    // Get the document from local database
    final documents = await _databaseService.getAllDocuments();
    final document = documents.firstWhere(
      (doc) => doc.id == documentId,
      orElse: () => Document(
        userId: 'unknown',
        title: '',
        category: '',
        filePaths: [],
        createdAt: amplify_core.TemporalDateTime.now(),
        lastModified: amplify_core.TemporalDateTime.now(),
        version: 0,
        syncState: SyncState.pending.toJson(),
      ),
    );

    if (document.title.isEmpty) {
      return;
    }

    // Update sync state
    final updatedDoc = document.copyWith(syncState: state.toJson());
    await _databaseService.updateDocument(updatedDoc);

    _emitEvent(SyncEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: SyncEventType.stateChanged.value,
      entityType: 'document',
      entityId: documentId.toString(),
      message: 'Sync state changed to ${state.name}',
      timestamp: amplify_core.TemporalDateTime.now(),
    ));
  }

  String _generateS3Key(String documentId, String filePath) {
    final fileName = filePath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'documents/$documentId/$timestamp-$fileName';
  }

  void _emitEvent(SyncEvent event) {
    if (!_syncEventController.isClosed) {
      _syncEventController.add(event);
    }
  }

  /// Helper to create SyncEvent with proper parameters
  SyncEvent _createSyncEvent(SyncEventType type,
      {String? entityId, String? message}) {
    return SyncEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: type.value,
      entityType: 'sync',
      entityId: entityId ?? 'global',
      message: message ?? '',
      timestamp: amplify_core.TemporalDateTime.now(),
    );
  }

  /// Batch sync multiple documents for efficiency
  /// Uploads up to 25 documents in a single batch operation
  Future<void> batchSyncDocuments(List<Document> documents) async {
    if (documents.isEmpty) {
      return;
    }

    try {
      _logInfo('Starting batch sync for ${documents.length} documents');

      // Update all documents to syncing state
      for (final doc in documents) {
        await _updateLocalDocumentSyncState(doc.id, SyncState.syncing);
      }

      // Batch upload documents
      await _documentSyncManager.batchUploadDocuments(documents);

      // Update all documents to synced state
      for (final doc in documents) {
        await _updateLocalDocumentSyncState(doc.id, SyncState.synced);
      }

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.syncCompleted.value,
        entityType: 'sync',
        entityId: 'batch',
        message: 'Batch synced ${documents.length} documents',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));

      _logInfo('Batch sync completed for ${documents.length} documents');
    } catch (e) {
      _logError('Error during batch sync: $e');

      // Mark all documents as error
      for (final doc in documents) {
        await _updateLocalDocumentSyncState(doc.id, SyncState.error);
      }

      rethrow;
    }
  }

  /// Update document with delta sync - only send changed fields
  /// More efficient than uploading the entire document
  Future<void> updateDocumentDelta(
    Document document,
    Map<String, dynamic> changedFields,
  ) async {
    final startTime = DateTime.now();
    try {
      // Update sync state to syncing
      await _updateLocalDocumentSyncState(document.id, SyncState.syncing);

      // Update document with delta
      await _documentSyncManager.updateDocumentDelta(document, changedFields);

      // Update sync state to synced
      await _updateLocalDocumentSyncState(document.id, SyncState.synced);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: true,
        latencyMs: latency,
        documentId: document.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.id.toString(),
        message:
            'Document updated with delta sync (${changedFields.keys.length} fields)',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } on VersionConflictException catch (e) {
      // Conflict detected
      await _updateLocalDocumentSyncState(document.id, SyncState.conflict);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.message,
        documentId: document.id.toString(),
      );

      _emitEvent(SyncEvent(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        eventType: SyncEventType.conflictDetected.value,
        entityType: 'document',
        entityId: document.id.toString(),
        message: 'Conflict detected: ${e.message}',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));

      rethrow;
    } catch (e) {
      await _updateLocalDocumentSyncState(document.id, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.id.toString(),
      );

      rethrow;
    }
  }

  /// Handle sign out by stopping all sync operations
  Future<void> handleSignOut() async {
    _logInfo('CloudSyncService: Handling sign out');

    // Stop all sync operations
    await stopSync();

    // Clear sync queue
    _syncQueue.clear();

    // Reset state
    _isInitialized = false;
    _isSyncing = false;
    _lastSyncTime = null;

    _logInfo('CloudSyncService: Sign out handled');
  }

  /// Clear user-specific sync settings for user isolation
  /// Called when user signs out to prevent sync settings leakage between users
  Future<void> clearUserSyncSettings() async {
    try {
      // Clear user-specific sync settings from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('sync_paused');
      await prefs.remove('sync_wifi_only');
      await prefs.remove('last_sync_time');
      await prefs.remove('sync_frequency');
      await prefs.remove('auto_sync_enabled');

      // Stop sync operations and clear state
      await handleSignOut();

      _logInfo(
          'CloudSyncService: User-specific settings cleared for user isolation');
    } catch (e) {
      _logError('Error clearing user sync settings: $e');
    }
  }

  /// Reset cloud sync service for new user session
  /// Called when a new user signs in to ensure clean sync state
  Future<void> resetForNewUser() async {
    await clearUserSyncSettings();
    _logInfo('CloudSyncService: Reset for new user session');
  }

  /// Enable bypass of subscription check (for testing only)
  /// WARNING: This should only be used for debugging sync issues
  static void enableSubscriptionBypass() {
    _bypassSubscriptionCheck = true;
    safePrint('⚠️ WARNING: Subscription bypass enabled for testing');
  }

  /// Disable bypass of subscription check
  static void disableSubscriptionBypass() {
    _bypassSubscriptionCheck = false;
    safePrint('Subscription bypass disabled');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopSync();
    await _connectivitySubscription?.cancel();
    await _syncEventController.close();
    // SimpleFileSyncManager doesn't need disposal
  }

  // Helper methods for logging
  void _logInfo(String message) =>
      _logService.log(message, level: app_log.LogLevel.info);
  void _logError(String message) =>
      _logService.log(message, level: app_log.LogLevel.error);
  void _logWarning(String message) =>
      _logService.log(message, level: app_log.LogLevel.warning);
  void _logDebug(String message) =>
      _logService.log(message, level: app_log.LogLevel.debug);

  /// Calculate a hash of current documents to detect changes
  Future<String> _calculateDocumentsHash() async {
    try {
      final documents = await _databaseService.getAllDocuments();
      final hashData = documents
          .map((doc) => '${doc.id}:${doc.version}:${doc.lastModified.format()}')
          .join('|');
      return hashData.hashCode.toString();
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }
}
