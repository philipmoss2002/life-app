import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';
import 'document_sync_manager.dart';
import 'simple_file_sync_manager.dart';
import 'database_service.dart';
import 'conflict_resolution_service.dart';

/// Represents a queued sync operation for offline-to-online transition
class QueuedSyncOperation {
  final String id;
  final String documentId;
  final QueuedOperationType type;
  final DateTime queuedAt;
  final int retryCount;
  final Map<String, dynamic> operationData;
  final int priority; // Higher number = higher priority

  QueuedSyncOperation({
    required this.id,
    required this.documentId,
    required this.type,
    required this.queuedAt,
    this.retryCount = 0,
    required this.operationData,
    this.priority = 0,
  });

  QueuedSyncOperation copyWith({
    String? id,
    String? documentId,
    QueuedOperationType? type,
    DateTime? queuedAt,
    int? retryCount,
    Map<String, dynamic>? operationData,
    int? priority,
  }) {
    return QueuedSyncOperation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      type: type ?? this.type,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      operationData: operationData ?? this.operationData,
      priority: priority ?? this.priority,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'type': type.name,
      'queuedAt': queuedAt.toIso8601String(),
      'retryCount': retryCount,
      'operationData': operationData,
      'priority': priority,
    };
  }

  static QueuedSyncOperation fromJson(Map<String, dynamic> json) {
    return QueuedSyncOperation(
      id: json['id'],
      documentId: json['documentId'],
      type: QueuedOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QueuedOperationType.upload,
      ),
      queuedAt: DateTime.parse(json['queuedAt']),
      retryCount: json['retryCount'] ?? 0,
      operationData: Map<String, dynamic>.from(json['operationData'] ?? {}),
      priority: json['priority'] ?? 0,
    );
  }
}

enum QueuedOperationType {
  upload,
  update,
  delete,
  fileUpload,
  fileDelete,
}

/// Service for managing offline sync queue and processing operations when online
class OfflineSyncQueueService {
  static final OfflineSyncQueueService _instance =
      OfflineSyncQueueService._internal();
  factory OfflineSyncQueueService() => _instance;
  OfflineSyncQueueService._internal();

  static const String _queueKey = 'offline_sync_queue';
  static const String _queueBackupKey = 'offline_sync_queue_backup';
  static const String _queueChecksumKey = 'offline_sync_queue_checksum';
  static const int _maxRetries = 5;

  final DocumentSyncManager _documentSyncManager = DocumentSyncManager();
  final SimpleFileSyncManager _fileSyncManager = SimpleFileSyncManager();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ConflictResolutionService _conflictService =
      ConflictResolutionService();

  final List<QueuedSyncOperation> _queue = [];
  final StreamController<QueueProcessingEvent> _eventController =
      StreamController<QueueProcessingEvent>.broadcast();

  bool _isProcessing = false;
  bool _queueCorrupted = false;
  DateTime? _lastSuccessfulPersist;

  /// Stream of queue processing events
  Stream<QueueProcessingEvent> get events => _eventController.stream;

  /// Initialize the service and load persisted queue
  Future<void> initialize() async {
    await _loadPersistedQueue();
    safePrint(
        'OfflineSyncQueueService initialized with ${_queue.length} queued operations');
  }

  /// Add an operation to the sync queue
  Future<void> queueOperation({
    required String documentId,
    required QueuedOperationType type,
    required Map<String, dynamic> operationData,
    int priority = 0,
  }) async {
    final operation = QueuedSyncOperation(
      id: '${type.name}_${documentId}_${DateTime.now().millisecondsSinceEpoch}',
      documentId: documentId,
      type: type,
      queuedAt: DateTime.now(),
      operationData: operationData,
      priority: priority,
    );

    // Check for consolidation opportunities before adding
    final consolidatedOperation = _consolidateWithExisting(operation);
    if (consolidatedOperation != null) {
      // Replace existing operation with consolidated one
      final existingIndex =
          _queue.indexWhere((op) => op.id == consolidatedOperation.id);
      if (existingIndex != -1) {
        _queue[existingIndex] = consolidatedOperation;
      } else {
        _queue.add(consolidatedOperation);
      }
    } else {
      _queue.add(operation);
    }

    // Sort queue by priority (higher priority first) and then by queued time
    _queue.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.queuedAt.compareTo(b.queuedAt);
    });

    await _persistQueue();

    _eventController.add(QueueProcessingEvent(
      type: QueueEventType.operationQueued,
      operationId: operation.id,
      message:
          'Operation queued: ${operation.type.name} for document ${operation.documentId}',
    ));

    safePrint(
        'Queued ${operation.type.name} operation for document ${operation.documentId}');
  }

  /// Process all queued operations in order with enhanced failure handling
  Future<void> processQueue() async {
    if (_isProcessing) {
      safePrint('Queue processing already in progress');
      return;
    }

    if (_queue.isEmpty) {
      safePrint('No operations in queue to process');
      return;
    }

    _isProcessing = true;
    safePrint('Starting queue processing with ${_queue.length} operations');

    _eventController.add(QueueProcessingEvent(
      type: QueueEventType.processingStarted,
      message: 'Started processing ${_queue.length} queued operations',
    ));

    // Create a snapshot of the queue before processing for failure recovery
    final queueSnapshot = List<QueuedSyncOperation>.from(_queue);
    final processedOperations = <String>[];
    final failedOperations = <QueuedSyncOperation>[];

    try {
      // Persist queue state before processing to ensure we can recover
      await _persistQueue();

      for (final operation in queueSnapshot) {
        try {
          await _processOperation(operation);
          processedOperations.add(operation.id);

          _eventController.add(QueueProcessingEvent(
            type: QueueEventType.operationCompleted,
            operationId: operation.id,
            message:
                'Completed ${operation.type.name} for document ${operation.documentId}',
          ));

          // Persist progress after each successful operation to prevent data loss
          if (processedOperations.length % 5 == 0) {
            await _persistIntermediateProgress(
                processedOperations, failedOperations);
          }
        } catch (e) {
          safePrint('Error processing operation ${operation.id}: $e');

          // Handle retry logic
          if (operation.retryCount < _maxRetries) {
            final retryOperation = operation.copyWith(
              retryCount: operation.retryCount + 1,
            );
            failedOperations.add(retryOperation);

            _eventController.add(QueueProcessingEvent(
              type: QueueEventType.operationRetry,
              operationId: operation.id,
              message:
                  'Retrying operation (attempt ${retryOperation.retryCount}/$_maxRetries)',
            ));
          } else {
            // Max retries exceeded - handle failure
            await _handleOperationFailure(operation, e);

            _eventController.add(QueueProcessingEvent(
              type: QueueEventType.operationFailed,
              operationId: operation.id,
              message:
                  'Operation failed after ${operation.retryCount} retries: $e',
            ));
          }
        }
      }

      // Update queue with processing results
      await _updateQueueAfterProcessing(processedOperations, failedOperations);

      _eventController.add(QueueProcessingEvent(
        type: QueueEventType.processingCompleted,
        message:
            'Queue processing completed. Processed: ${processedOperations.length}, Failed: ${failedOperations.length}, Remaining: ${_queue.length}',
      ));

      safePrint(
          'Queue processing completed. Processed: ${processedOperations.length}, Failed: ${failedOperations.length}, Remaining: ${_queue.length}');
    } catch (criticalError) {
      safePrint('Critical error during queue processing: $criticalError');

      // Preserve queue state on critical failure
      await _handleQueueProcessingFailure(
          queueSnapshot, processedOperations, failedOperations, criticalError);
    } finally {
      _isProcessing = false;
    }
  }

  /// Handle critical failures during queue processing
  Future<void> _handleQueueProcessingFailure(
    List<QueuedSyncOperation> originalQueue,
    List<String> processedOperations,
    List<QueuedSyncOperation> failedOperations,
    Object error,
  ) async {
    safePrint('Handling queue processing failure: $error');

    try {
      // Restore queue to pre-processing state, removing only successfully processed operations
      _queue.clear();
      _queue.addAll(
          originalQueue.where((op) => !processedOperations.contains(op.id)));

      // Add failed operations back with updated retry counts
      _queue.addAll(failedOperations);

      // Re-sort queue
      _queue.sort((a, b) {
        final priorityComparison = b.priority.compareTo(a.priority);
        if (priorityComparison != 0) return priorityComparison;
        return a.queuedAt.compareTo(b.queuedAt);
      });

      // Persist the recovered queue state
      await _persistQueue();

      _eventController.add(QueueProcessingEvent(
        type: QueueEventType.processingFailed,
        message:
            'Queue processing failed, preserved ${_queue.length} operations for retry: $error',
      ));

      safePrint(
          'Queue state preserved after processing failure. ${_queue.length} operations remain.');
    } catch (recoveryError) {
      safePrint(
          'Failed to preserve queue state after processing failure: $recoveryError');

      _eventController.add(QueueProcessingEvent(
        type: QueueEventType.queueCorrupted,
        message:
            'Failed to preserve queue after processing failure: $recoveryError',
      ));
    }
  }

  /// Persist intermediate progress during queue processing
  Future<void> _persistIntermediateProgress(
    List<String> processedOperations,
    List<QueuedSyncOperation> failedOperations,
  ) async {
    try {
      // Create a temporary updated queue state
      final tempQueue = List<QueuedSyncOperation>.from(_queue);

      // Remove processed operations
      tempQueue.removeWhere((op) => processedOperations.contains(op.id));

      // Add failed operations with updated retry counts
      tempQueue.addAll(failedOperations);

      // Store intermediate state
      final prefs = await SharedPreferences.getInstance();
      final tempQueueJson =
          jsonEncode(tempQueue.map((op) => op.toJson()).toList());
      await prefs.setString('${_queueKey}_temp', tempQueueJson);
    } catch (e) {
      safePrint('Failed to persist intermediate progress: $e');
      // Don't throw - this is just for safety
    }
  }

  /// Update queue after processing completion
  Future<void> _updateQueueAfterProcessing(
    List<String> processedOperations,
    List<QueuedSyncOperation> failedOperations,
  ) async {
    try {
      // Remove successfully processed operations from queue
      _queue.removeWhere((op) => processedOperations.contains(op.id));

      // Add failed operations back to queue for retry
      _queue.addAll(failedOperations);

      // Re-sort queue
      _queue.sort((a, b) {
        final priorityComparison = b.priority.compareTo(a.priority);
        if (priorityComparison != 0) return priorityComparison;
        return a.queuedAt.compareTo(b.queuedAt);
      });

      // Persist the updated queue
      await _persistQueue();

      // Clean up temporary state
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_queueKey}_temp');
    } catch (e) {
      safePrint('Error updating queue after processing: $e');

      // Try to recover from temporary state
      await _recoverFromTemporaryState();
    }
  }

  /// Recover queue from temporary state if main update fails
  Future<void> _recoverFromTemporaryState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tempQueueJson = prefs.getString('${_queueKey}_temp');

      if (tempQueueJson != null) {
        final tempQueueData = jsonDecode(tempQueueJson) as List<dynamic>;
        _queue.clear();
        _queue.addAll(tempQueueData.map((item) =>
            QueuedSyncOperation.fromJson(item as Map<String, dynamic>)));

        await _persistQueue();
        await prefs.remove('${_queueKey}_temp');

        safePrint('Successfully recovered queue from temporary state');
      }
    } catch (e) {
      safePrint('Failed to recover from temporary state: $e');
    }
  }

  /// Get current queue status
  QueueStatus getQueueStatus() {
    return QueueStatus(
      totalOperations: _queue.length,
      isProcessing: _isProcessing,
      operationsByType: _getOperationsByType(),
      oldestOperation: _queue.isNotEmpty ? _queue.first.queuedAt : null,
    );
  }

  /// Clear all operations from the queue
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();

    _eventController.add(QueueProcessingEvent(
      type: QueueEventType.queueCleared,
      message: 'Queue cleared',
    ));

    safePrint('Sync queue cleared');
  }

  /// Get operations for a specific document
  List<QueuedSyncOperation> getOperationsForDocument(String documentId) {
    return _queue.where((op) => op.documentId == documentId).toList();
  }

  /// Remove operations for a specific document
  Future<void> removeOperationsForDocument(String documentId) async {
    final removedCount = _queue.length;
    _queue.removeWhere((op) => op.documentId == documentId);
    final finalCount = _queue.length;

    if (removedCount != finalCount) {
      await _persistQueue();
      safePrint(
          'Removed ${removedCount - finalCount} operations for document $documentId');
    }
  }

  // Private methods

  /// Process a single queued operation
  Future<void> _processOperation(QueuedSyncOperation operation) async {
    safePrint(
        'Processing ${operation.type.name} operation for document ${operation.documentId}');

    switch (operation.type) {
      case QueuedOperationType.upload:
        await _processDocumentUpload(operation);
        break;
      case QueuedOperationType.update:
        await _processDocumentUpdate(operation);
        break;
      case QueuedOperationType.delete:
        await _processDocumentDelete(operation);
        break;
      case QueuedOperationType.fileUpload:
        await _processFileUpload(operation);
        break;
      case QueuedOperationType.fileDelete:
        await _processFileDelete(operation);
        break;
    }
  }

  /// Process document upload operation
  Future<void> _processDocumentUpload(QueuedSyncOperation operation) async {
    final documentData =
        operation.operationData['document'] as Map<String, dynamic>;
    final document = Document.fromJson(documentData);

    try {
      await _documentSyncManager.uploadDocument(document);

      // Update local document sync state
      final updatedDocument =
          document.copyWith(syncState: SyncState.synced.toJson());
      await _databaseService.updateDocument(updatedDocument);
    } catch (e) {
      // Check if this is a conflict
      if (e is VersionConflictException) {
        await _handleConflictDuringQueueProcessing(operation, e);
        return; // Don't rethrow - conflict is handled
      }
      rethrow;
    }
  }

  /// Process document update operation
  Future<void> _processDocumentUpdate(QueuedSyncOperation operation) async {
    final documentData =
        operation.operationData['document'] as Map<String, dynamic>;
    final document = Document.fromJson(documentData);

    try {
      await _documentSyncManager.updateDocument(document);

      // Update local document sync state
      final updatedDocument =
          document.copyWith(syncState: SyncState.synced.toJson());
      await _databaseService.updateDocument(updatedDocument);
    } catch (e) {
      // Check if this is a conflict
      if (e is VersionConflictException) {
        await _handleConflictDuringQueueProcessing(operation, e);
        return; // Don't rethrow - conflict is handled
      }
      rethrow;
    }
  }

  /// Process document delete operation
  Future<void> _processDocumentDelete(QueuedSyncOperation operation) async {
    final documentId = operation.documentId;

    await _documentSyncManager.deleteDocument(documentId);

    // Remove from local database if it exists
    try {
      final documents = await _databaseService.getAllDocuments();
      final document = documents.firstWhere(
        (doc) => doc.id.toString() == documentId,
        orElse: () => Document(
          userId: '',
          title: '',
          category: '',
          filePaths: [],
          createdAt: TemporalDateTime.now(),
          lastModified: TemporalDateTime.now(),
          version: 0,
          syncState: SyncState.notSynced.toJson(),
        ),
      );

      if (document.title.isNotEmpty) {
        await _databaseService.deleteDocument(int.parse(document.id));
      }
    } catch (e) {
      safePrint('Error removing document from local database: $e');
      // Don't rethrow - remote delete was successful
    }
  }

  /// Process file upload operation
  Future<void> _processFileUpload(QueuedSyncOperation operation) async {
    final filePath = operation.operationData['filePath'] as String;
    final documentId = operation.documentId;

    await _fileSyncManager.uploadFile(filePath, documentId);
  }

  /// Process file delete operation
  Future<void> _processFileDelete(QueuedSyncOperation operation) async {
    final s3Key = operation.operationData['s3Key'] as String;

    await _fileSyncManager.deleteFile(s3Key);
  }

  /// Handle conflicts that occur during queue processing
  Future<void> _handleConflictDuringQueueProcessing(
    QueuedSyncOperation operation,
    VersionConflictException conflict,
  ) async {
    safePrint(
        'Conflict detected during queue processing for document ${operation.documentId}');

    // Register the conflict with the conflict resolution service
    await _conflictService.registerConflict(
      documentId: operation.documentId,
      localDocument: conflict.localDocument,
      remoteDocument: conflict.remoteDocument,
      conflictType: ConflictType.versionMismatch,
    );

    // Update local document to conflict state
    final conflictDocument = conflict.localDocument.copyWith(
      syncState: SyncState.conflict.toJson(),
    );
    await _databaseService.updateDocument(conflictDocument);

    _eventController.add(QueueProcessingEvent(
      type: QueueEventType.conflictDetected,
      operationId: operation.id,
      message:
          'Conflict detected for document ${operation.documentId} during queue processing',
    ));
  }

  /// Handle operation failure after max retries
  Future<void> _handleOperationFailure(
      QueuedSyncOperation operation, Object error) async {
    safePrint('Operation ${operation.id} failed permanently: $error');

    // Mark document as error state if it's a document operation
    if (operation.type == QueuedOperationType.upload ||
        operation.type == QueuedOperationType.update ||
        operation.type == QueuedOperationType.delete) {
      try {
        final documents = await _databaseService.getAllDocuments();
        final document = documents.firstWhere(
          (doc) => doc.id.toString() == operation.documentId,
          orElse: () => Document(
            userId: '',
            title: '',
            category: '',
            filePaths: [],
            createdAt: TemporalDateTime.now(),
            lastModified: TemporalDateTime.now(),
            version: 0,
            syncState: SyncState.notSynced.toJson(),
          ),
        );

        if (document.title.isNotEmpty) {
          final errorDocument =
              document.copyWith(syncState: SyncState.error.toJson());
          await _databaseService.updateDocument(errorDocument);
        }
      } catch (e) {
        safePrint('Error updating document error state: $e');
      }
    }
  }

  /// Consolidate operation with existing operations in queue
  /// Enhanced consolidation logic to optimize queue processing efficiency
  QueuedSyncOperation? _consolidateWithExisting(
      QueuedSyncOperation newOperation) {
    // Find existing operations for the same document
    final existingOperations =
        _queue.where((op) => op.documentId == newOperation.documentId).toList();

    if (existingOperations.isEmpty) {
      return null;
    }

    // Enhanced consolidation rules for Requirements 10.3:
    // 1. Delete operations cancel all previous operations for the document
    // 2. Multiple updates consolidate into the latest update with most recent data
    // 3. Upload followed by updates consolidates into upload with latest data
    // 4. Multiple file operations of same type consolidate into latest
    // 5. File operations preserve ordering requirements with document operations
    // 6. Priority is preserved as maximum of consolidated operations

    if (newOperation.type == QueuedOperationType.delete) {
      // Delete cancels all previous operations for this document
      _queue.removeWhere((op) => op.documentId == newOperation.documentId);
      return newOperation;
    }

    // Sort existing operations by queue time to process in order
    existingOperations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

    QueuedSyncOperation? consolidatedOperation;
    final operationsToRemove = <String>[];

    for (final existing in existingOperations) {
      if (existing.type == QueuedOperationType.delete) {
        // Can't consolidate with delete - it should be processed first
        continue;
      }

      // Document operation consolidation
      if (_canConsolidateDocumentOperations(newOperation, existing)) {
        consolidatedOperation =
            _consolidateDocumentOperations(newOperation, existing);
        operationsToRemove.add(existing.id);
      }
      // File operation consolidation
      else if (_canConsolidateFileOperations(newOperation, existing)) {
        consolidatedOperation =
            _consolidateFileOperations(newOperation, existing);
        operationsToRemove.add(existing.id);
      }
    }

    // Remove consolidated operations from queue
    if (consolidatedOperation != null) {
      _queue.removeWhere((op) => operationsToRemove.contains(op.id));
      return consolidatedOperation;
    }

    return null;
  }

  /// Check if two document operations can be consolidated
  bool _canConsolidateDocumentOperations(
      QueuedSyncOperation newOp, QueuedSyncOperation existingOp) {
    // Document operations that can be consolidated
    final documentOps = {
      QueuedOperationType.upload,
      QueuedOperationType.update,
    };

    return documentOps.contains(newOp.type) &&
        documentOps.contains(existingOp.type);
  }

  /// Check if two file operations can be consolidated
  bool _canConsolidateFileOperations(
      QueuedSyncOperation newOp, QueuedSyncOperation existingOp) {
    // File operations that can be consolidated
    final fileOps = {
      QueuedOperationType.fileUpload,
      QueuedOperationType.fileDelete,
    };

    return fileOps.contains(newOp.type) &&
        fileOps.contains(existingOp.type) &&
        newOp.type == existingOp.type; // Same file operation type
  }

  /// Consolidate document operations (upload/update)
  QueuedSyncOperation _consolidateDocumentOperations(
      QueuedSyncOperation newOp, QueuedSyncOperation existingOp) {
    // Determine the final operation type
    QueuedOperationType finalType;
    if (existingOp.type == QueuedOperationType.upload) {
      // Keep upload type - it's the initial creation
      finalType = QueuedOperationType.upload;
    } else {
      // Use the new operation type
      finalType = newOp.type;
    }

    // Merge operation data, preserving the latest document state
    final mergedData = Map<String, dynamic>.from(existingOp.operationData);
    mergedData.addAll(newOp.operationData);

    return existingOp.copyWith(
      type: finalType,
      operationData: mergedData,
      priority: math.max(existingOp.priority, newOp.priority),
      retryCount: 0, // Reset retry count for consolidated operation
    );
  }

  /// Consolidate file operations of the same type
  QueuedSyncOperation _consolidateFileOperations(
      QueuedSyncOperation newOp, QueuedSyncOperation existingOp) {
    // For file operations, use the latest operation data
    final mergedData = Map<String, dynamic>.from(existingOp.operationData);
    mergedData.addAll(newOp.operationData);

    return existingOp.copyWith(
      operationData: mergedData,
      priority: math.max(existingOp.priority, newOp.priority),
      retryCount: 0, // Reset retry count for consolidated operation
    );
  }

  /// Get consolidation statistics for monitoring
  Map<String, int> getConsolidationStats() {
    final stats = <String, int>{};
    final documentGroups = <String, List<QueuedSyncOperation>>{};

    // Group operations by document
    for (final operation in _queue) {
      documentGroups.putIfAbsent(operation.documentId, () => []).add(operation);
    }

    // Count potential consolidations
    int consolidatableDocuments = 0;
    int totalConsolidatableOps = 0;

    for (final entry in documentGroups.entries) {
      final operations = entry.value;
      if (operations.length > 1) {
        // Check if operations can be consolidated
        final documentOps = operations
            .where((op) =>
                op.type == QueuedOperationType.upload ||
                op.type == QueuedOperationType.update)
            .length;

        if (documentOps > 1) {
          consolidatableDocuments++;
          totalConsolidatableOps += documentOps;
        }
      }
    }

    stats['consolidatable_documents'] = consolidatableDocuments;
    stats['consolidatable_operations'] = totalConsolidatableOps;
    stats['total_documents'] = documentGroups.length;
    stats['total_operations'] = _queue.length;

    return stats;
  }

  /// Consolidate all operations in the queue for maximum efficiency
  /// This method should be called before processing the queue to optimize performance
  Future<int> consolidateQueue() async {
    if (_queue.isEmpty) {
      return 0;
    }

    final originalCount = _queue.length;
    final documentGroups = <String, List<QueuedSyncOperation>>{};

    // Group operations by document
    for (final operation in _queue) {
      documentGroups.putIfAbsent(operation.documentId, () => []).add(operation);
    }

    final consolidatedOperations = <QueuedSyncOperation>[];

    // Process each document group for consolidation
    for (final entry in documentGroups.entries) {
      final operations = entry.value;

      if (operations.length == 1) {
        // No consolidation needed for single operations
        consolidatedOperations.addAll(operations);
        continue;
      }

      // Sort operations by queue time to maintain ordering
      operations.sort((a, b) => a.queuedAt.compareTo(b.queuedAt));

      final consolidatedForDocument =
          _consolidateDocumentOperationsList(operations);
      consolidatedOperations.addAll(consolidatedForDocument);
    }

    // Replace queue with consolidated operations
    _queue.clear();
    _queue.addAll(consolidatedOperations);

    // Re-sort by priority and time
    _queue.sort((a, b) {
      final priorityComparison = b.priority.compareTo(a.priority);
      if (priorityComparison != 0) return priorityComparison;
      return a.queuedAt.compareTo(b.queuedAt);
    });

    // Persist the consolidated queue
    await _persistQueue();

    final consolidatedCount = originalCount - _queue.length;

    if (consolidatedCount > 0) {
      _eventController.add(QueueProcessingEvent(
        type: QueueEventType.operationQueued, // Reusing existing event type
        message:
            'Consolidated $consolidatedCount operations, ${_queue.length} operations remaining',
      ));

      safePrint(
          'Queue consolidation completed: $consolidatedCount operations consolidated');
    }

    return consolidatedCount;
  }

  /// Consolidate operations for a single document
  List<QueuedSyncOperation> _consolidateDocumentOperationsList(
      List<QueuedSyncOperation> operations) {
    if (operations.length <= 1) {
      return operations;
    }

    final result = <QueuedSyncOperation>[];
    QueuedSyncOperation? currentDocumentOp;
    final fileOperations = <QueuedSyncOperation>[];

    for (final operation in operations) {
      switch (operation.type) {
        case QueuedOperationType.delete:
          // Delete cancels all previous operations
          result.clear();
          fileOperations.clear();
          result.add(operation);
          currentDocumentOp = null;
          break;

        case QueuedOperationType.upload:
        case QueuedOperationType.update:
          if (currentDocumentOp == null) {
            currentDocumentOp = operation;
          } else {
            // Consolidate with existing document operation
            currentDocumentOp =
                _consolidateDocumentOperations(operation, currentDocumentOp);
          }
          break;

        case QueuedOperationType.fileUpload:
        case QueuedOperationType.fileDelete:
          // Group file operations by type and file path
          final existingFileOpIndex = fileOperations.indexWhere((op) =>
              op.type == operation.type &&
              op.operationData['filePath'] ==
                  operation.operationData['filePath']);

          if (existingFileOpIndex != -1) {
            // Replace with newer file operation
            fileOperations[existingFileOpIndex] = operation;
          } else {
            fileOperations.add(operation);
          }
          break;
      }
    }

    // Add consolidated document operation if exists
    if (currentDocumentOp != null) {
      result.add(currentDocumentOp);
    }

    // Add file operations
    result.addAll(fileOperations);

    return result;
  }

  /// Optimize queue processing by consolidating before processing
  Future<void> processQueueWithConsolidation() async {
    // First consolidate the queue for maximum efficiency
    final consolidatedCount = await consolidateQueue();

    safePrint(
        'Pre-processing consolidation: $consolidatedCount operations consolidated');

    // Then process the consolidated queue
    await processQueue();
  }

  /// Load persisted queue from storage with corruption detection and recovery
  Future<void> _loadPersistedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Try to load the main queue first
      bool mainQueueLoaded = await _loadQueueFromKey(prefs, _queueKey);

      if (!mainQueueLoaded) {
        safePrint(
            'Main queue corrupted or missing, attempting backup recovery');

        // Try to load from backup
        bool backupLoaded = await _loadQueueFromKey(prefs, _queueBackupKey);

        if (backupLoaded) {
          safePrint('Successfully recovered queue from backup');
          // Restore main queue from backup
          await _persistQueue();
        } else {
          safePrint(
              'Both main and backup queues are corrupted, starting with empty queue');
          _queue.clear();
          _queueCorrupted = true;
        }
      }

      // Sort queue by priority and time
      _queue.sort((a, b) {
        final priorityComparison = b.priority.compareTo(a.priority);
        if (priorityComparison != 0) return priorityComparison;
        return a.queuedAt.compareTo(b.queuedAt);
      });
    } catch (e) {
      safePrint('Critical error loading persisted queue: $e');
      await _handleQueueCorruption(e);
    }
  }

  /// Load queue from a specific storage key with integrity verification
  Future<bool> _loadQueueFromKey(SharedPreferences prefs, String key) async {
    try {
      final queueJson = prefs.getString(key);
      if (queueJson == null) {
        return false;
      }

      // Verify queue integrity if we have a checksum
      if (key == _queueKey) {
        final storedChecksum = prefs.getString(_queueChecksumKey);
        if (storedChecksum != null) {
          final calculatedChecksum = _calculateChecksum(queueJson);
          if (storedChecksum != calculatedChecksum) {
            safePrint('Queue checksum mismatch - queue may be corrupted');
            return false;
          }
        }
      }

      final queueData = jsonDecode(queueJson) as List<dynamic>;
      _queue.clear();

      // Validate each operation during loading
      for (final item in queueData) {
        try {
          final operation =
              QueuedSyncOperation.fromJson(item as Map<String, dynamic>);
          if (_validateOperation(operation)) {
            _queue.add(operation);
          } else {
            safePrint(
                'Invalid operation found during queue loading: ${operation.id}');
          }
        } catch (e) {
          safePrint('Error parsing operation during queue loading: $e');
          // Continue loading other operations
        }
      }

      return true;
    } catch (e) {
      safePrint('Error loading queue from key $key: $e');
      return false;
    }
  }

  /// Validate a queued operation for integrity
  bool _validateOperation(QueuedSyncOperation operation) {
    // Check required fields
    if (operation.id.isEmpty || operation.documentId.isEmpty) {
      return false;
    }

    // Check operation type is valid
    if (!QueuedOperationType.values.contains(operation.type)) {
      return false;
    }

    // Check timestamps are reasonable
    final now = DateTime.now();
    if (operation.queuedAt.isAfter(now.add(Duration(minutes: 5)))) {
      return false; // Future timestamp is suspicious
    }

    // Check retry count is reasonable
    if (operation.retryCount < 0 || operation.retryCount > _maxRetries * 2) {
      return false;
    }

    // Check operation data exists
    if (operation.operationData.isEmpty) {
      return false;
    }

    return true;
  }

  /// Calculate checksum for queue data integrity verification
  String _calculateChecksum(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Persist queue to storage with backup and integrity verification
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((op) => op.toJson()).toList());

      // Create backup of current queue before overwriting
      final currentQueue = prefs.getString(_queueKey);
      if (currentQueue != null) {
        await prefs.setString(_queueBackupKey, currentQueue);
      }

      // Calculate and store checksum for integrity verification
      final checksum = _calculateChecksum(queueJson);
      await prefs.setString(_queueChecksumKey, checksum);

      // Store the new queue
      await prefs.setString(_queueKey, queueJson);

      _lastSuccessfulPersist = DateTime.now();
      _queueCorrupted = false;
    } catch (e) {
      safePrint('Error persisting queue: $e');
      await _handlePersistenceFailure(e);
    }
  }

  /// Handle queue persistence failures
  Future<void> _handlePersistenceFailure(Object error) async {
    safePrint('Queue persistence failed: $error');

    _eventController.add(QueueProcessingEvent(
      type: QueueEventType.queuePersistenceError,
      message: 'Failed to persist queue: $error',
    ));

    // Try alternative persistence strategies
    try {
      // Attempt to persist with reduced data (remove operation data if too large)
      final simplifiedQueue = _queue
          .map((op) => QueuedSyncOperation(
                id: op.id,
                documentId: op.documentId,
                type: op.type,
                queuedAt: op.queuedAt,
                retryCount: op.retryCount,
                operationData: {'simplified': true}, // Minimal data
                priority: op.priority,
              ))
          .toList();

      final prefs = await SharedPreferences.getInstance();
      final simplifiedJson =
          jsonEncode(simplifiedQueue.map((op) => op.toJson()).toList());
      await prefs.setString('${_queueKey}_emergency', simplifiedJson);

      safePrint('Emergency queue persistence successful');
    } catch (emergencyError) {
      safePrint('Emergency queue persistence also failed: $emergencyError');
      _queueCorrupted = true;
    }
  }

  /// Handle queue corruption scenarios
  Future<void> _handleQueueCorruption(Object error) async {
    safePrint('Queue corruption detected: $error');

    _queueCorrupted = true;
    _queue.clear();

    _eventController.add(QueueProcessingEvent(
      type: QueueEventType.queueCorrupted,
      message: 'Queue corruption detected and cleared: $error',
    ));

    // Try to recover any emergency backup
    try {
      final prefs = await SharedPreferences.getInstance();
      final emergencyQueue = prefs.getString('${_queueKey}_emergency');

      if (emergencyQueue != null) {
        final queueData = jsonDecode(emergencyQueue) as List<dynamic>;
        for (final item in queueData) {
          try {
            final operation =
                QueuedSyncOperation.fromJson(item as Map<String, dynamic>);
            if (_validateOperation(operation)) {
              _queue.add(operation);
            }
          } catch (e) {
            // Skip invalid operations
          }
        }

        if (_queue.isNotEmpty) {
          safePrint(
              'Recovered ${_queue.length} operations from emergency backup');
          await _persistQueue(); // Try to restore normal persistence
        }
      }
    } catch (recoveryError) {
      safePrint('Emergency recovery failed: $recoveryError');
    }
  }

  /// Recover queue from corruption or failure
  Future<bool> recoverQueue() async {
    safePrint('Attempting queue recovery...');

    try {
      final prefs = await SharedPreferences.getInstance();

      // Try backup first
      bool recovered = await _loadQueueFromKey(prefs, _queueBackupKey);

      if (recovered) {
        safePrint('Queue recovered from backup');
        await _persistQueue(); // Restore main queue
        return true;
      }

      // Try emergency backup
      final emergencyQueue = prefs.getString('${_queueKey}_emergency');
      if (emergencyQueue != null) {
        final queueData = jsonDecode(emergencyQueue) as List<dynamic>;
        _queue.clear();

        for (final item in queueData) {
          try {
            final operation =
                QueuedSyncOperation.fromJson(item as Map<String, dynamic>);
            if (_validateOperation(operation)) {
              _queue.add(operation);
            }
          } catch (e) {
            // Skip invalid operations
          }
        }

        if (_queue.isNotEmpty) {
          safePrint('Queue recovered from emergency backup');
          await _persistQueue();
          return true;
        }
      }

      safePrint('No recoverable queue data found');
      return false;
    } catch (e) {
      safePrint('Queue recovery failed: $e');
      return false;
    }
  }

  /// Check queue health and integrity
  Future<QueueHealthStatus> checkQueueHealth() async {
    final issues = <String>[];

    // Check if queue is corrupted
    if (_queueCorrupted) {
      issues.add('Queue marked as corrupted');
    }

    // Check last successful persist time
    if (_lastSuccessfulPersist != null) {
      final timeSinceLastPersist =
          DateTime.now().difference(_lastSuccessfulPersist!);
      if (timeSinceLastPersist.inHours > 24) {
        issues.add('No successful persistence in over 24 hours');
      }
    }

    // Check for invalid operations
    int invalidOperations = 0;
    for (final operation in _queue) {
      if (!_validateOperation(operation)) {
        invalidOperations++;
      }
    }

    if (invalidOperations > 0) {
      issues.add('$invalidOperations invalid operations detected');
    }

    // Check queue size
    if (_queue.length > 1000) {
      issues.add('Queue size is very large (${_queue.length} operations)');
    }

    // Check for very old operations
    final now = DateTime.now();
    int oldOperations = 0;
    for (final operation in _queue) {
      if (now.difference(operation.queuedAt).inDays > 7) {
        oldOperations++;
      }
    }

    if (oldOperations > 0) {
      issues.add('$oldOperations operations older than 7 days');
    }

    return QueueHealthStatus(
      isHealthy: issues.isEmpty,
      issues: issues,
      totalOperations: _queue.length,
      invalidOperations: invalidOperations,
      oldOperations: oldOperations,
      lastSuccessfulPersist: _lastSuccessfulPersist,
    );
  }

  /// Clean up invalid or corrupted operations from queue
  Future<int> cleanupQueue() async {
    final originalCount = _queue.length;

    // Remove invalid operations
    _queue.removeWhere((operation) => !_validateOperation(operation));

    // Remove very old operations (older than 30 days)
    final cutoffDate = DateTime.now().subtract(Duration(days: 30));
    _queue.removeWhere((operation) => operation.queuedAt.isBefore(cutoffDate));

    // Remove operations with excessive retry counts
    _queue.removeWhere((operation) => operation.retryCount > _maxRetries * 2);

    final removedCount = originalCount - _queue.length;

    if (removedCount > 0) {
      await _persistQueue();
      safePrint('Cleaned up $removedCount invalid/old operations from queue');

      _eventController.add(QueueProcessingEvent(
        type: QueueEventType.queueCleaned,
        message: 'Removed $removedCount invalid/old operations from queue',
      ));
    }

    return removedCount;
  }

  /// Get operations grouped by type
  Map<QueuedOperationType, int> _getOperationsByType() {
    final result = <QueuedOperationType, int>{};
    for (final operation in _queue) {
      result[operation.type] = (result[operation.type] ?? 0) + 1;
    }
    return result;
  }

  /// Clear user-specific sync queue data for user isolation
  /// Called when user signs out to prevent sync operations from affecting other users
  Future<void> clearUserSyncQueue() async {
    try {
      // Clear in-memory queue
      _queue.clear();

      // Clear persisted queue data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_queueBackupKey);
      await prefs.remove(_queueChecksumKey);
      await prefs.remove('${_queueKey}_temp');
      await prefs.remove('${_queueKey}_emergency');

      // Reset state
      _isProcessing = false;
      _queueCorrupted = false;
      _lastSuccessfulPersist = null;

      _eventController.add(QueueProcessingEvent(
        type: QueueEventType.queueCleared,
        message: 'User sync queue cleared for user isolation',
      ));

      safePrint(
          'OfflineSyncQueue: User-specific data cleared for user isolation');
    } catch (e) {
      safePrint('Error clearing user sync queue: $e');
    }
  }

  /// Reset sync queue for new user session
  /// Called when a new user signs in to ensure clean sync state
  Future<void> resetForNewUser() async {
    await clearUserSyncQueue();
    await initialize(); // Reinitialize with clean state
    safePrint('OfflineSyncQueue: Reset for new user session');
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _eventController.close();
  }
}

/// Queue processing event
class QueueProcessingEvent {
  final QueueEventType type;
  final String? operationId;
  final String message;
  final DateTime timestamp;

  QueueProcessingEvent({
    required this.type,
    this.operationId,
    required this.message,
  }) : timestamp = DateTime.now();
}

enum QueueEventType {
  operationQueued,
  processingStarted,
  operationCompleted,
  operationRetry,
  operationFailed,
  conflictDetected,
  processingCompleted,
  processingFailed,
  queueCleared,
  queueCorrupted,
  queueCleaned,
  queuePersistenceError,
}

/// Queue status information
class QueueStatus {
  final int totalOperations;
  final bool isProcessing;
  final Map<QueuedOperationType, int> operationsByType;
  final DateTime? oldestOperation;

  QueueStatus({
    required this.totalOperations,
    required this.isProcessing,
    required this.operationsByType,
    this.oldestOperation,
  });
}

/// Queue health status information
class QueueHealthStatus {
  final bool isHealthy;
  final List<String> issues;
  final int totalOperations;
  final int invalidOperations;
  final int oldOperations;
  final DateTime? lastSuccessfulPersist;

  QueueHealthStatus({
    required this.isHealthy,
    required this.issues,
    required this.totalOperations,
    required this.invalidOperations,
    required this.oldOperations,
    this.lastSuccessfulPersist,
  });

  @override
  String toString() {
    return 'QueueHealthStatus(isHealthy: $isHealthy, issues: $issues, '
        'totalOperations: $totalOperations, invalidOperations: $invalidOperations, '
        'oldOperations: $oldOperations, lastSuccessfulPersist: $lastSuccessfulPersist)';
  }
}
