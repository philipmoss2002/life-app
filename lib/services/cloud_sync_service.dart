import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/Document.dart';
import '../models/sync_event.dart' show LocalSyncEvent, SyncEventType;
import '../models/sync_state.dart';
import 'document_sync_manager.dart';
import 'simple_file_sync_manager.dart';
import 'authentication_service.dart';
import 'subscription_service.dart' as sub;
import 'database_service.dart';
import 'analytics_service.dart';
import 'offline_sync_queue_service.dart';
import 'deletion_tracking_service.dart';
import 'sync_error_handler.dart';
import 'sync_identifier_service.dart';
import 'backward_compatibility_service.dart';
import 'sync_state_manager.dart';

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
  final String? syncId; // Universal sync identifier for document matching
  final SyncOperationType type;
  final DateTime queuedAt;
  final int retryCount;
  final Document? document;

  SyncOperation({
    required this.id,
    required this.documentId,
    this.syncId,
    required this.type,
    DateTime? queuedAt,
    this.retryCount = 0,
    this.document,
  }) : queuedAt = queuedAt ?? DateTime.now();

  SyncOperation copyWith({
    String? id,
    String? documentId,
    String? syncId,
    SyncOperationType? type,
    DateTime? queuedAt,
    int? retryCount,
    Document? document,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      syncId: syncId ?? this.syncId,
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

  // UUID generator
  final Uuid _uuid = Uuid();

  // Dependencies
  final DocumentSyncManager _documentSyncManager = DocumentSyncManager();
  final SimpleFileSyncManager _fileSyncManager = SimpleFileSyncManager();
  final AuthenticationService _authService = AuthenticationService();
  final sub.SubscriptionService _subscriptionService =
      sub.SubscriptionService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final DeletionTrackingService _deletionTrackingService =
      DeletionTrackingService();
  final Connectivity _connectivity = Connectivity();
  final AnalyticsService _analyticsService = AnalyticsService();
  final OfflineSyncQueueService _queueService = OfflineSyncQueueService();
  final app_log.LogService _logService = app_log.LogService();
  final SyncErrorHandler _errorHandler = SyncErrorHandler();
  final BackwardCompatibilityService _backwardCompatibilityService =
      BackwardCompatibilityService();
  late final SyncStateManager _syncStateManager;

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
  final StreamController<LocalSyncEvent> _syncEventController =
      StreamController<LocalSyncEvent>.broadcast();

  /// Stream of sync events
  Stream<LocalSyncEvent> get syncEvents => _syncEventController.stream;

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

      // Initialize sync state manager
      _syncStateManager = SyncStateManager(
        databaseService: _databaseService,
        logService: _logService,
      );

      // Schedule periodic tombstone cleanup (daily)
      _scheduleTombstoneCleanup();

      _isInitialized = true;
      _logInfo('CloudSyncService initialized successfully');

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.syncStarted.value,
        entityType: 'sync',
        entityId: 'service',
        message: 'Sync service initialized',
        timestamp: amplify_core.TemporalDateTime.now(),
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

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
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

    _emitEvent(LocalSyncEvent(
      id: _uuid.v4(),
      eventType: SyncEventType.syncCompleted.value,
      entityType: 'sync',
      entityId: 'service',
      message: 'Automatic sync stopped',
      timestamp: amplify_core.TemporalDateTime.now(),
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

      // Queue documents pending deletion first
      await _queueDocumentsPendingDeletion();

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

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.syncCompleted.value,
        entityType: 'sync',
        entityId: 'global',
        message: 'Sync completed successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      _logError('Error during sync: $e');
      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.syncFailed.value,
        entityType: 'sync',
        entityId: 'global',
        message: 'Sync failed: $e',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
      rethrow;
    }
  }

  /// Mark a document for deletion with tombstone tracking
  ///
  /// This method should be called when a user deletes a document.
  /// It creates a tombstone to prevent the document from being reinstated during sync.
  ///
  /// [syncId] - The sync identifier of the document to delete
  /// [deletedBy] - Identifier of the user/device performing the deletion
  /// [reason] - Reason for deletion (default: 'user')
  Future<void> markDocumentForDeletion(Document document, String deletedBy,
      {String reason = 'user'}) async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _logInfo(
          'Marking document for deletion: ${document.title} (ID: ${document.syncId})');

      // Use deletion tracking service to handle the complete deletion workflow
      await _deletionTrackingService.markDocumentForDeletion(
        document,
        user.id,
        deletedBy,
        reason: reason,
      );

      // Queue the document for sync processing
      final operation = SyncOperation(
        id: _uuid.v4(),
        documentId: document.syncId,
        syncId: document.syncId,
        type: SyncOperationType.delete,
        document: document,
      );

      _syncQueue.add(operation);
      _logInfo('Document queued for deletion sync: ${document.title}');

      // Trigger sync if conditions are met
      final connectivityResult = await _connectivity.checkConnectivity();
      if (await _shouldSync(connectivityResult)) {
        _logInfo('Sync conditions met, processing deletion immediately');
        await _processSyncQueue();
      } else {
        _logInfo(
            'Sync conditions not met, deletion will be processed when sync is available');
      }
    } catch (e) {
      _logError('Error marking document for deletion: $e');
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

  /// Queue a document for synchronization using sync identifier
  ///
  /// [document] - The document to sync
  /// [type] - The type of sync operation (upload, update, delete)
  ///
  /// The sync identifier from the document will be used for operation tracking
  /// and consolidation with other operations for the same document.
  Future<void> queueDocumentSync(
      Document document, SyncOperationType type) async {
    final operation = SyncOperation(
      id: _uuid.v4(),
      documentId: document.syncId,
      syncId: document.syncId,
      type: type,
      document: document,
    );

    // Check for consolidation opportunities before adding
    final consolidatedOperation = _consolidateWithExisting(operation);
    if (consolidatedOperation != null) {
      // Replace existing operation with consolidated one
      final existingIndex = _syncQueue.indexWhere((op) =>
          op.syncId == consolidatedOperation.syncId &&
          op.id == consolidatedOperation.id);
      if (existingIndex != -1) {
        _syncQueue[existingIndex] = consolidatedOperation;
        _logInfo(
            'Consolidated sync operation: ${consolidatedOperation.type} for document ${consolidatedOperation.syncId ?? consolidatedOperation.documentId}');
      } else {
        _syncQueue.add(consolidatedOperation);
        _logInfo(
            'Queued consolidated sync operation: ${consolidatedOperation.type} for document ${consolidatedOperation.syncId ?? consolidatedOperation.documentId}');
      }
    } else {
      _syncQueue.add(operation);
      _logInfo(
          'Queued sync operation: ${operation.type} for document ${operation.syncId ?? operation.documentId}');
    }

    // Update document sync state to pending
    try {
      await _updateLocalDocumentSyncState(document.syncId, SyncState.pending);
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

  /// Resolve a conflict using sync identifier
  ///
  /// [syncId] - The sync identifier of the document with conflict
  /// [resolution] - The conflict resolution strategy to apply
  Future<void> resolveConflict(
    String syncId,
    ConflictResolution resolution,
  ) async {
    // This will be implemented in the conflict resolution service
    // For now, just log the resolution
    _logInfo(
        'Resolving conflict for document with syncId $syncId using strategy: $resolution');
  }

  /// Queue a document for synchronization by sync identifier
  ///
  /// [syncId] - The sync identifier of the document to sync
  /// [type] - The type of sync operation (upload, update, delete)
  ///
  /// This method looks up the document by sync identifier and queues it for sync.
  Future<void> queueDocumentSyncBySyncId(
    String syncId,
    SyncOperationType type,
  ) async {
    // Validate sync identifier format
    SyncIdentifierService.validateOrThrow(syncId,
        context: 'document sync queueing');

    try {
      // Get the document by sync identifier
      final documents = await _databaseService.getAllDocuments();
      final document = documents.firstWhere(
        (doc) => doc.syncId == syncId,
        orElse: () => throw ArgumentError(
            'Document not found with syncId: "$syncId" for sync queueing'),
      );

      // Queue the document for sync
      await queueDocumentSync(document, type);

      _logInfo(
          'Queued document for sync by syncId: $syncId, type: ${type.name}');
    } catch (e) {
      _logError('Error queuing document sync by syncId $syncId: $e');
      rethrow;
    }
  }

  /// Get sync status for a specific document by sync identifier
  ///
  /// [syncId] - The sync identifier of the document
  /// Returns the current sync state and any pending operations for the document
  Future<Map<String, dynamic>> getDocumentSyncStatus(String syncId) async {
    // Validate sync identifier format
    SyncIdentifierService.validateOrThrow(syncId,
        context: 'sync status retrieval');

    try {
      // Get the document by sync identifier
      final documents = await _databaseService.getAllDocuments();
      final document = documents.firstWhere(
        (doc) => doc.syncId == syncId,
        orElse: () => throw ArgumentError(
            'Document not found with syncId: "$syncId" for sync status retrieval'),
      );

      // Check for pending operations in sync queue
      final pendingOperations = _syncQueue
          .where((op) => op.syncId == syncId)
          .map((op) => {
                'id': op.id,
                'type': op.type.name,
                'queuedAt': op.queuedAt.toIso8601String(),
                'retryCount': op.retryCount,
              })
          .toList();

      return {
        'syncId': syncId,
        'syncState': document.syncState,
        'version': document.version,
        'lastModified': document.lastModified.format(),
        'pendingOperations': pendingOperations,
        'hasPendingOperations': pendingOperations.isNotEmpty,
      };
    } catch (e) {
      _logError('Error getting sync status for syncId $syncId: $e');
      rethrow;
    }
  }

  /// Cancel pending sync operations for a document by sync identifier
  ///
  /// [syncId] - The sync identifier of the document
  /// Returns the number of operations cancelled
  Future<int> cancelPendingSyncOperations(String syncId) async {
    // Validate sync identifier format
    SyncIdentifierService.validateOrThrow(syncId,
        context: 'sync operation cancellation');

    try {
      final initialCount = _syncQueue.length;
      _syncQueue.removeWhere((op) => op.syncId == syncId);
      final cancelledCount = initialCount - _syncQueue.length;

      if (cancelledCount > 0) {
        _logInfo(
            'Cancelled $cancelledCount pending sync operations for syncId: $syncId');

        // Emit event about cancelled operations
        _emitEvent(LocalSyncEvent(
          id: _uuid.v4(),
          eventType: 'operations_cancelled',
          entityType: 'document',
          entityId: syncId,
          message: 'Cancelled $cancelledCount pending sync operations',
          timestamp: amplify_core.TemporalDateTime.now(),
        ));
      }

      return cancelledCount;
    } catch (e) {
      _logError('Error cancelling sync operations for syncId $syncId: $e');
      rethrow;
    }
  }

  // Private methods

  /// Consolidate operation with existing operations in queue by sync identifier
  ///
  /// Enhanced consolidation logic to optimize queue processing efficiency.
  /// Operations for the same sync identifier are consolidated according to these rules:
  /// 1. Delete operations cancel all previous operations for the sync identifier
  /// 2. Multiple updates consolidate into the latest update with most recent data
  /// 3. Upload followed by updates consolidates into upload with latest data
  SyncOperation? _consolidateWithExisting(SyncOperation newOperation) {
    if (newOperation.syncId == null) {
      return null; // Cannot consolidate operations without sync identifiers
    }

    // Find existing operations for the same sync identifier
    final existingOperations =
        _syncQueue.where((op) => op.syncId == newOperation.syncId).toList();

    if (existingOperations.isEmpty) {
      return null;
    }

    // Delete operations cancel all previous operations for this sync identifier
    if (newOperation.type == SyncOperationType.delete) {
      _syncQueue.removeWhere((op) => op.syncId == newOperation.syncId);
      return newOperation;
    }

    // Sort existing operations by queue time to process in order
    existingOperations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    SyncOperation? consolidatedOperation;
    final operationsToRemove = <String>[];

    for (final existing in existingOperations) {
      if (existing.type == SyncOperationType.delete) {
        // Can't consolidate with delete - it should be processed first
        continue;
      }

      // Document operation consolidation
      if (_canConsolidateDocumentOperations(newOperation, existing)) {
        consolidatedOperation =
            _consolidateDocumentOperations(newOperation, existing);
        operationsToRemove.add(existing.id);
      }
    }

    // Remove consolidated operations from queue
    if (consolidatedOperation != null) {
      _syncQueue.removeWhere((op) => operationsToRemove.contains(op.id));
      return consolidatedOperation;
    }

    return null;
  }

  /// Check if two document operations can be consolidated
  bool _canConsolidateDocumentOperations(
      SyncOperation newOp, SyncOperation existingOp) {
    // Document operations that can be consolidated
    final documentOps = {
      SyncOperationType.upload,
      SyncOperationType.update,
    };

    return documentOps.contains(newOp.type) &&
        documentOps.contains(existingOp.type) &&
        newOp.syncId == existingOp.syncId;
  }

  /// Consolidate document operations (upload/update) by sync identifier
  SyncOperation _consolidateDocumentOperations(
      SyncOperation newOp, SyncOperation existingOp) {
    // Determine the final operation type
    SyncOperationType finalType;
    if (existingOp.type == SyncOperationType.upload) {
      // Keep upload type - it's the initial creation
      finalType = SyncOperationType.upload;
    } else {
      // Use the new operation type
      finalType = newOp.type;
    }

    // Use the most recent document data
    final finalDocument = newOp.document ?? existingOp.document;

    return existingOp.copyWith(
      type: finalType,
      document: finalDocument,
      retryCount: 0, // Reset retry count for consolidated operation
    );
  }

  void _setupConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _handleConnectivityChange(results);
      },
    );
  }

  /// Schedule periodic tombstone cleanup to prevent unbounded growth
  void _scheduleTombstoneCleanup() {
    // Run cleanup daily at 2 AM local time
    Timer.periodic(const Duration(hours: 24), (timer) async {
      try {
        _logInfo('Starting scheduled tombstone cleanup');
        final deletedCount =
            await _deletionTrackingService.cleanupOldTombstones();
        _logInfo(
            'Scheduled tombstone cleanup completed: $deletedCount tombstones removed');
      } catch (e) {
        _logError('Error during scheduled tombstone cleanup: $e');
      }
    });

    // Also run cleanup immediately if it's been more than 7 days since last cleanup
    _runInitialTombstoneCleanupIfNeeded();
  }

  /// Run initial tombstone cleanup if needed
  Future<void> _runInitialTombstoneCleanupIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCleanup = prefs.getInt('last_tombstone_cleanup') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;

      if (now - lastCleanup > sevenDaysMs) {
        _logInfo(
            'Running initial tombstone cleanup (last cleanup was more than 7 days ago)');
        final deletedCount =
            await _deletionTrackingService.cleanupOldTombstones();
        await prefs.setInt('last_tombstone_cleanup', now);
        _logInfo(
            'Initial tombstone cleanup completed: $deletedCount tombstones removed');
      }
    } catch (e) {
      _logError('Error during initial tombstone cleanup: $e');
    }
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

    // Consolidate operations by sync identifier before processing
    await _consolidateQueueBySyncId();

    final operations = List<SyncOperation>.from(_syncQueue);
    _syncQueue.clear();

    for (final operation in operations) {
      try {
        await _processSyncOperation(operation);
      } catch (e) {
        _logError('Error processing sync operation: $e');

        // Enhanced retry logic with sync identifier-based idempotency
        if (operation.retryCount < 5) {
          final retryId = operation.syncId != null
              ? '${operation.syncId}_${operation.type.name}_retry_${operation.retryCount + 1}'
              : '${operation.documentId}_${operation.type.name}_retry_${operation.retryCount + 1}';

          final updatedOperation = operation.copyWith(
            id: retryId, // Use sync identifier for idempotent retry IDs
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

          _emitEvent(LocalSyncEvent(
            id: _uuid.v4(),
            eventType: SyncEventType.syncFailed.value,
            entityType: 'document',
            entityId: operation.syncId ?? operation.documentId,
            message: 'Max retries reached for sync operation',
            timestamp: amplify_core.TemporalDateTime.now(),
          ));
        }
      }
    }
  }

  /// Consolidate all operations in the queue by sync identifier for maximum efficiency
  Future<void> _consolidateQueueBySyncId() async {
    if (_syncQueue.isEmpty) {
      return;
    }

    final originalCount = _syncQueue.length;
    final syncIdGroups = <String, List<SyncOperation>>{};

    // Group operations by sync identifier
    for (final operation in _syncQueue) {
      final key = operation.syncId ?? operation.documentId;
      syncIdGroups.putIfAbsent(key, () => []).add(operation);
    }

    final consolidatedOperations = <SyncOperation>[];

    // Process each sync identifier group for consolidation
    for (final entry in syncIdGroups.entries) {
      final operations = entry.value;

      if (operations.length == 1) {
        // No consolidation needed for single operations
        consolidatedOperations.addAll(operations);
        continue;
      }

      // Sort operations by queue time to maintain ordering
      operations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      final consolidatedForSyncId = _consolidateOperationsList(operations);
      consolidatedOperations.addAll(consolidatedForSyncId);
    }

    // Replace queue with consolidated operations
    _syncQueue.clear();
    _syncQueue.addAll(consolidatedOperations);

    final consolidatedCount = originalCount - _syncQueue.length;

    if (consolidatedCount > 0) {
      _logInfo(
          'Queue consolidation completed: $consolidatedCount operations consolidated, ${_syncQueue.length} operations remaining');
    }
  }

  /// Consolidate operations for a single sync identifier
  List<SyncOperation> _consolidateOperationsList(
      List<SyncOperation> operations) {
    if (operations.length <= 1) {
      return operations;
    }

    final result = <SyncOperation>[];
    SyncOperation? currentDocumentOp;

    for (final operation in operations) {
      switch (operation.type) {
        case SyncOperationType.delete:
          // Delete cancels all previous operations
          result.clear();
          result.add(operation);
          currentDocumentOp = null;
          break;

        case SyncOperationType.upload:
        case SyncOperationType.update:
          if (currentDocumentOp == null) {
            currentDocumentOp = operation;
          } else {
            // Consolidate with existing document operation
            currentDocumentOp =
                _consolidateDocumentOperations(operation, currentDocumentOp);
          }
          break;
      }
    }

    // Add consolidated document operation if exists
    if (currentDocumentOp != null) {
      result.add(currentDocumentOp);
    }

    return result;
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

      _logInfo('🔄 Starting upload for document: ${document.syncId}');
      _logInfo('📁 File paths: ${document.filePaths}');

      // Update sync state to syncing
      await _updateLocalDocumentSyncState(document.syncId, SyncState.syncing);

      // Upload file attachments first and get S3 keys
      Document documentToUpload = document;
      if (document.filePaths.isNotEmpty) {
        _logInfo('📤 Uploading ${document.filePaths.length} files...');
        final fileStartTime = DateTime.now();

        try {
          final uploadResults = await _fileSyncManager.uploadFilesParallel(
            document.filePaths,
            document.syncId,
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
            documentId: document.syncId,
          );
        } catch (e) {
          _errorHandler.logError(document, 'file upload', e.toString());
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
        if (uploadedDocument.syncId != document.syncId) {
          _logInfo(
              '🔄 Updating local document with DynamoDB ID: ${uploadedDocument.syncId}');
          _logInfo('📝 Original local ID was: ${document.syncId}');

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
      await _updateLocalDocumentSyncState(document.syncId, SyncState.synced);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document upload analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpload,
        success: true,
        latencyMs: latency,
        documentId: document.syncId,
        syncId: document.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.syncId,
        syncId: document.syncId,
        message: 'Document uploaded successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
        metadata: {
          'documentTitle': document.title,
          'version': document.version,
          'fileCount': document.filePaths.length,
        },
      ));
    } catch (e) {
      await _updateLocalDocumentSyncState(document.syncId, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed upload analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpload,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.syncId,
        syncId: document.syncId,
      );

      rethrow;
    }
  }

  Future<void> _updateDocument(Document document) async {
    final startTime = DateTime.now();
    try {
      // Update sync state to syncing
      await _updateLocalDocumentSyncState(document.syncId, SyncState.syncing);

      // Update document metadata
      await _documentSyncManager.updateDocument(document);

      // Update sync state to synced
      await _updateLocalDocumentSyncState(document.syncId, SyncState.synced);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: true,
        latencyMs: latency,
        documentId: document.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.syncId,
        syncId: document.syncId,
        message: 'Document updated successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
        metadata: {
          'documentTitle': document.title,
          'version': document.version,
        },
      ));
    } on VersionConflictException catch (e) {
      // Conflict detected
      await _updateLocalDocumentSyncState(document.syncId, SyncState.conflict);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.message,
        documentId: document.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.conflictDetected.value,
        entityType: 'document',
        entityId: document.syncId,
        message: 'Conflict detected: ${e.message}',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));

      rethrow;
    } catch (e) {
      await _updateLocalDocumentSyncState(document.syncId, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.syncId,
      );

      rethrow;
    }
  }

  Future<void> _deleteDocument(Document document) async {
    final startTime = DateTime.now();
    try {
      _logInfo('Document sync state: ${document.syncState}');
      _logInfo('Document ID: ${document.syncId}');

      // Parse sync state from document
      final syncState = SyncState.fromJson(document.syncState);

      // Check document ID format (UUID vs integer)
      final isUuidFormat = RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(document.syncId);
      _logInfo('Document ID format check: $isUuidFormat');

      // CRITICAL FIX: Check if remote deletion is needed
      // Documents with pendingDeletion, synced, or conflict states need remote deletion
      final needsRemoteDeletion = syncState == SyncState.synced ||
          syncState == SyncState.conflict ||
          syncState == SyncState.pendingDeletion;

      if (needsRemoteDeletion) {
        _logInfo('Document needs remote deletion, processing...');

        // Update sync state to syncing
        await _updateLocalDocumentSyncState(document.syncId, SyncState.syncing);

        // Delete document from remote DynamoDB using syncId
        try {
          if (document.syncId != null && document.syncId!.isNotEmpty) {
            await _documentSyncManager.deleteDocument(document.syncId!);
            _logInfo(
                'Document deleted from DynamoDB using syncId: ${document.syncId}');
          } else {
            _logWarning(
                'Document has no syncId, cannot delete from remote: ${document.title}');
          }
        } catch (e) {
          _logError('Failed to delete document from DynamoDB: $e');
          // Continue with file deletion even if DynamoDB deletion fails
        }

        // Delete files from S3 using FileAttachment records for accurate paths
        try {
          final fileAttachments = await _databaseService
              .getFileAttachmentsWithLabels(int.parse(document.syncId));
          if (fileAttachments.isNotEmpty) {
            _logInfo(
                'Found ${fileAttachments.length} file attachments to delete from S3');
            for (final attachment in fileAttachments) {
              final fileStartTime = DateTime.now();
              try {
                _logInfo('Deleting file from S3: ${attachment.s3Key}');
                await _fileSyncManager.deleteFile(attachment.s3Key);
                final fileLatency =
                    DateTime.now().difference(fileStartTime).inMilliseconds;

                // Track file delete analytics
                await _analyticsService.trackSyncEvent(
                  type: AnalyticsSyncEventType.fileDelete,
                  success: true,
                  latencyMs: fileLatency,
                  documentId: document.syncId,
                );
                _logInfo(
                    'Successfully deleted file from S3: ${attachment.s3Key}');
              } catch (e) {
                _logError('Failed to delete file ${attachment.s3Key}: $e');
                // Continue with other files instead of failing completely
              }
            }
          } else {
            _logInfo(
                'Files were never uploaded to S3, skipping remote file deletion');
          }
        } catch (e) {
          _logError('Error getting file attachments for deletion: $e');
          // Fallback to using document.filePaths if FileAttachment query fails
          for (final s3Key in document.filePaths) {
            final fileStartTime = DateTime.now();
            try {
              _logInfo('Fallback: Deleting file from S3: $s3Key');
              await _fileSyncManager.deleteFile(s3Key);
              final fileLatency =
                  DateTime.now().difference(fileStartTime).inMilliseconds;

              // Track file delete analytics
              await _analyticsService.trackSyncEvent(
                type: AnalyticsSyncEventType.fileDelete,
                success: true,
                latencyMs: fileLatency,
                documentId: document.syncId,
              );
            } catch (e) {
              _logError('Failed to delete file $s3Key: $e');
              // Continue with other files instead of failing completely
            }
          }
        }

        // Delete FileAttachment records from local database
        try {
          final fileAttachments = await _databaseService
              .getFileAttachmentsWithLabels(int.parse(document.syncId));
          if (fileAttachments.isNotEmpty) {
            _logInfo(
                'FileAttachments were never synced to DynamoDB, skipping remote deletion');
          }
        } catch (e) {
          _logError('Error checking FileAttachment records: $e');
        }
      } else {
        _logInfo(
            'Document was never synced to remote (syncState: $syncState), skipping remote deletion: ${document.title}');
      }

      // Complete deletion using deletion tracking service
      await _deletionTrackingService.completeDeletion(document);
      _logInfo('Document deletion completed: ${document.title}');

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document delete analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentDelete,
        success: true,
        latencyMs: latency,
        documentId: document.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.syncId,
        message: 'Document deleted successfully',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } catch (e) {
      await _updateLocalDocumentSyncState(document.syncId, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed delete analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentDelete,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.syncId,
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
      final allRemoteDocuments =
          await _documentSyncManager.fetchAllDocuments(user.id);

      // Filter out tombstoned documents to prevent reinstating deleted documents
      final remoteDocuments = await _deletionTrackingService
          .filterTombstonedDocuments(allRemoteDocuments);

      if (allRemoteDocuments.length > remoteDocuments.length) {
        final filteredCount =
            allRemoteDocuments.length - remoteDocuments.length;
        _logInfo(
            'Filtered out $filteredCount tombstoned documents from remote sync');
      }

      // Get local documents
      final localDocuments = await _databaseService.getAllDocuments();

      // Sync remote documents to local
      for (final remoteDoc in remoteDocuments) {
        // Try to find matching local document by syncId first
        Document? localDoc = localDocuments.firstWhere(
          (doc) => doc.syncId != null && doc.syncId == remoteDoc.syncId,
          orElse: () => Document(
            syncId: SyncIdentifierService.generateValidated(),
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

        // If not found by syncId, try to find by legacy ID matching (for migration compatibility)
        // Only use legacy matching if not all documents have sync identifiers
        if (localDoc.title.isEmpty &&
            await _backwardCompatibilityService.shouldUseLegacyMatching()) {
          localDoc = localDocuments.firstWhere(
            (doc) => doc.syncId.toString() == remoteDoc.syncId,
            orElse: () => Document(
              syncId: SyncIdentifierService.generateValidated(),
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

          // If we found a potential match by legacy ID, update the local document with the syncId
          if (localDoc.title.isNotEmpty) {
            _logInfo('🔍 Found document by legacy ID match: ${localDoc.title}');
            _logInfo(
                '🔄 Updating local document with syncId: ${remoteDoc.syncId}');

            // The syncId is immutable in the Document model, so we'll just continue processing
            // The document already has the correct syncId from the remote
            _logInfo('✅ Document already has correct syncId');

            // Clear backward compatibility cache since we just updated a document
            _backwardCompatibilityService.clearStatusCache();
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
          await _fileSyncManager.downloadFile(s3Key, remoteDoc.syncId);
          final fileLatency =
              DateTime.now().difference(fileStartTime).inMilliseconds;

          // Track file download analytics
          await _analyticsService.trackSyncEvent(
            type: AnalyticsSyncEventType.fileDownload,
            success: true,
            latencyMs: fileLatency,
            documentId: remoteDoc.syncId,
          );
        } catch (e) {
          _logError('Failed to download file $s3Key: $e');
          // Continue with other files instead of failing completely
        }
      }

      // Update or insert document in local database
      final existingDoc = await _databaseService.getAllDocuments();

      // Check for existing document using sync identifier first, then legacy ID if backward compatibility is enabled
      bool docExists = existingDoc
          .any((doc) => doc.syncId != null && doc.syncId == remoteDoc.syncId);

      // Only check legacy ID matching if backward compatibility is enabled and no sync ID match found
      if (!docExists &&
          await _backwardCompatibilityService.shouldUseLegacyMatching()) {
        docExists = existingDoc.any((doc) => doc.syncId == remoteDoc.syncId);
      }

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
        documentId: remoteDoc.syncId,
        syncId: remoteDoc.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.documentDownloaded.value,
        entityType: 'document',
        entityId: remoteDoc.syncId,
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
        documentId: remoteDoc.syncId,
      );

      rethrow;
    }
  }

  /// Update sync state using sync identifier instead of document ID
  ///
  /// [syncId] - The sync identifier of the document
  /// [state] - The new sync state to set
  /// [metadata] - Optional metadata about the state change
  Future<void> _updateSyncStateBySyncId(String syncId, SyncState state,
      {Map<String, dynamic>? metadata}) async {
    try {
      await _syncStateManager.updateSyncState(syncId, state,
          metadata: metadata);
    } catch (e) {
      _logError(
          'Failed to update sync state for syncId: $syncId to ${state.name}: $e');
      rethrow;
    }
  }

  /// Legacy method for backward compatibility - converts document ID to sync ID
  Future<void> _updateLocalDocumentSyncState(
      String documentId, SyncState state) async {
    try {
      // Find document by ID to get sync identifier
      final documents = await _databaseService.getAllDocuments();
      final document = documents.firstWhere(
        (doc) => doc.syncId == documentId,
        orElse: () => Document(
          syncId: SyncIdentifierService.generateValidated(),
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
        _logWarning('Document not found for ID: $documentId');
        return;
      }

      // Use sync identifier if available, otherwise fall back to old behavior
      if (document.syncId != null && document.syncId!.isNotEmpty) {
        await _updateSyncStateBySyncId(document.syncId!, state);
      } else {
        // Legacy fallback - update document directly
        final updatedDoc = document.copyWith(syncState: state.toJson());
        await _databaseService.updateDocument(updatedDoc);

        _emitEvent(LocalSyncEvent(
          id: _uuid.v4(),
          eventType: SyncEventType.stateChanged.value,
          entityType: 'document',
          entityId: documentId,
          message: 'Sync state changed to ${state.name}',
          timestamp: amplify_core.TemporalDateTime.now(),
        ));
      }
    } catch (e) {
      _logError('Failed to update sync state for document ID: $documentId: $e');
      rethrow;
    }
  }

  /// Query documents by sync state, returning their sync identifiers
  Future<List<String>> getDocumentsBySyncState(SyncState state) async {
    return await _syncStateManager.getDocumentsBySyncState(state);
  }

  /// Get sync state for a document by sync identifier
  Future<SyncState?> getSyncStateBySyncId(String syncId) async {
    return await _syncStateManager.getSyncState(syncId);
  }

  /// Get sync state history for a document by sync identifier
  List<SyncStateHistoryEntry> getSyncStateHistory(String syncId) {
    return _syncStateManager.getSyncStateHistory(syncId);
  }

  /// Mark document for deletion using sync identifier
  Future<void> markDocumentForDeletionBySyncId(String syncId,
      {Map<String, dynamic>? metadata}) async {
    await _syncStateManager.markForDeletion(syncId, metadata: metadata);
  }

  String _generateS3Key(String documentId, String filePath) {
    final fileName = filePath.split('/').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'documents/$documentId/$timestamp-$fileName';
  }

  void _emitEvent(LocalSyncEvent event) {
    if (!_syncEventController.isClosed) {
      _syncEventController.add(event);
    }
  }

  /// Helper to get current user ID
  Future<String> _getCurrentUserId() async {
    try {
      final user = await _authService.getCurrentUser();
      return user?.id ?? 'anonymous';
    } catch (e) {
      _logWarning('Failed to get current user ID: $e');
      return 'anonymous';
    }
  }

  /// Helper to create SyncEvent with proper parameters including sync identifier
  Future<LocalSyncEvent> _createSyncEvent(SyncEventType type,
      {String? entityId,
      String? syncId,
      String? message,
      Map<String, dynamic>? metadata}) async {
    final userId = await _getCurrentUserId();
    return LocalSyncEvent(
      id: _uuid.v4(),
      eventType: type.value,
      entityType: 'sync',
      entityId: entityId ?? 'global',
      syncId: syncId,
      message: message ?? '',
      timestamp: amplify_core.TemporalDateTime.now(),
      metadata: metadata,
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

      // Update all documents to syncing state using sync identifiers
      for (final doc in documents) {
        if (doc.syncId != null && doc.syncId!.isNotEmpty) {
          await _updateSyncStateBySyncId(doc.syncId!, SyncState.syncing);
        } else {
          // Fallback for documents without sync identifiers
          await _updateLocalDocumentSyncState(doc.syncId, SyncState.syncing);
        }
      }

      // Batch upload documents
      await _documentSyncManager.batchUploadDocuments(documents);

      // Update all documents to synced state using sync identifiers
      for (final doc in documents) {
        if (doc.syncId != null && doc.syncId!.isNotEmpty) {
          await _updateSyncStateBySyncId(doc.syncId!, SyncState.synced);
        } else {
          // Fallback for documents without sync identifiers
          await _updateLocalDocumentSyncState(doc.syncId, SyncState.synced);
        }
      }

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.syncCompleted.value,
        entityType: 'sync',
        entityId: 'batch',
        message: 'Batch synced ${documents.length} documents',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));

      _logInfo('Batch sync completed for ${documents.length} documents');
    } catch (e) {
      _logError('Error during batch sync: $e');

      // Mark all documents as error using sync identifiers
      for (final doc in documents) {
        if (doc.syncId != null && doc.syncId!.isNotEmpty) {
          await _updateSyncStateBySyncId(doc.syncId!, SyncState.error);
        } else {
          // Fallback for documents without sync identifiers
          await _updateLocalDocumentSyncState(doc.syncId, SyncState.error);
        }
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
      // Update sync state to syncing using sync identifier
      if (document.syncId != null && document.syncId!.isNotEmpty) {
        await _updateSyncStateBySyncId(document.syncId!, SyncState.syncing);
      } else {
        await _updateLocalDocumentSyncState(document.syncId, SyncState.syncing);
      }

      // Update document with delta
      await _documentSyncManager.updateDocumentDelta(document, changedFields);

      // Update sync state to synced using sync identifier
      if (document.syncId != null && document.syncId!.isNotEmpty) {
        await _updateSyncStateBySyncId(document.syncId!, SyncState.synced);
      } else {
        await _updateLocalDocumentSyncState(document.syncId, SyncState.synced);
      }

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track document update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: true,
        latencyMs: latency,
        documentId: document.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.documentUploaded.value,
        entityType: 'document',
        entityId: document.syncId,
        syncId: document.syncId, // Include sync identifier in event
        message:
            'Document updated with delta sync (${changedFields.keys.length} fields)',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));
    } on VersionConflictException catch (e) {
      // Conflict detected - use sync identifier
      if (document.syncId != null && document.syncId!.isNotEmpty) {
        await _updateSyncStateBySyncId(document.syncId!, SyncState.conflict);
      } else {
        await _updateLocalDocumentSyncState(
            document.syncId, SyncState.conflict);
      }

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.message,
        documentId: document.syncId,
      );

      _emitEvent(LocalSyncEvent(
        id: _uuid.v4(),
        eventType: SyncEventType.conflictDetected.value,
        entityType: 'document',
        entityId: document.syncId,
        message: 'Conflict detected: ${e.message}',
        timestamp: amplify_core.TemporalDateTime.now(),
      ));

      rethrow;
    } catch (e) {
      await _updateLocalDocumentSyncState(document.syncId, SyncState.error);

      final latency = DateTime.now().difference(startTime).inMilliseconds;

      // Track failed update analytics
      await _analyticsService.trackSyncEvent(
        type: AnalyticsSyncEventType.documentUpdate,
        success: false,
        latencyMs: latency,
        errorMessage: e.toString(),
        documentId: document.syncId,
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

  /// Dispose of resources and clean up
  void dispose() {
    _syncStateManager.dispose();
    _syncEventController.close();
    _connectivitySubscription?.cancel();
    _periodicSyncTimer?.cancel();
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
          .map((doc) =>
              '${doc.syncId}:${doc.version}:${doc.lastModified.format()}')
          .join('|');
      return hashData.hashCode.toString();
    } catch (e) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Queue documents that are pending deletion for sync processing
  Future<void> _queueDocumentsPendingDeletion() async {
    try {
      // Get current user
      final user = await _authService.getCurrentUser();
      if (user == null) {
        _logWarning('User not authenticated, skipping deletion queue');
        return;
      }

      // Get documents pending deletion using deletion tracking service
      final documentsToDelete =
          await _deletionTrackingService.getDocumentsPendingDeletion(user.id);

      if (documentsToDelete.isNotEmpty) {
        _logInfo(
            'Found ${documentsToDelete.length} documents pending deletion, queuing for sync');

        for (final document in documentsToDelete) {
          final operation = SyncOperation(
            id: _uuid.v4(),
            documentId: document.syncId,
            syncId: document.syncId,
            type: SyncOperationType.delete,
            document: document,
          );

          _syncQueue.add(operation);
          _logInfo(
              'Queued sync operation: ${operation.type} for document ${document.syncId ?? document.syncId}');
        }

        _logInfo('Queued ${documentsToDelete.length} documents for deletion');
      }
    } catch (e) {
      _logError('Error queuing documents for deletion: $e');
    }
  }
}
