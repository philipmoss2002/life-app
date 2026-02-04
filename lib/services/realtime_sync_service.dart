import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart' as amplify_doc;
import '../models/new_document.dart' as local;
import '../models/sync_state.dart';
import '../repositories/document_repository.dart';
import 'auth_token_manager.dart';

/// Service responsible for real-time synchronization using GraphQL subscriptions
/// Handles subscription setup, event processing, and local database updates
class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  // Subscription management
  StreamSubscription<GraphQLResponse<amplify_doc.Document>>?
      _documentCreateSubscription;
  StreamSubscription<GraphQLResponse<amplify_doc.Document>>?
      _documentUpdateSubscription;
  StreamSubscription<GraphQLResponse<amplify_doc.Document>>?
      _documentDeleteSubscription;

  // Event controllers for UI notifications
  StreamController<SyncEventNotification> _syncEventController =
      StreamController<SyncEventNotification>.broadcast();

  // Background notification queue
  final List<SyncEventNotification> _backgroundNotificationQueue = [];
  bool _isAppInBackground = false;

  // Connection state tracking
  bool _isSubscriptionActive = false;
  Timer? _reconnectionTimer;
  int _reconnectionAttempts = 0;
  static const int _maxReconnectionAttempts = 5;
  static const Duration _baseReconnectionDelay = Duration(seconds: 2);

  // Services
  final DocumentRepository _documentRepository = DocumentRepository();
  final AuthTokenManager _authManager = AuthTokenManager();

  /// Stream of sync events for UI consumption
  Stream<SyncEventNotification> get syncEvents => _syncEventController.stream;

  /// Whether real-time sync is currently active
  bool get isActive => _isSubscriptionActive;

  /// Start real-time synchronization for the current authenticated user
  Future<void> startRealtimeSync([String? userId]) async {
    try {
      // Validate authentication before starting subscriptions
      await _authManager.validateTokenBeforeOperation();

      // Get current user ID if not provided
      final currentUserId = userId ?? await _authManager.getCurrentUserId();

      if (currentUserId == null) {
        throw Exception(
            'Unable to get current user ID - user may not be authenticated');
      }

      safePrint('Starting real-time sync for user: $currentUserId');

      // Stop any existing subscriptions
      await stopRealtimeSync();

      // Start subscriptions for document operations
      await _startDocumentCreateSubscription(currentUserId);
      await _startDocumentUpdateSubscription(currentUserId);
      await _startDocumentDeleteSubscription(currentUserId);

      _isSubscriptionActive = true;
      _reconnectionAttempts = 0;

      safePrint('Real-time sync started successfully');

      // Notify UI of successful connection
      _addSyncEvent(SyncEventNotification(
        type: SyncEventType.connectionEstablished,
        message: 'Real-time sync connected',
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      safePrint('Failed to start real-time sync: $e');
      _handleSubscriptionError(e);
    }
  }

  /// Stop real-time synchronization
  Future<void> stopRealtimeSync() async {
    safePrint('Stopping real-time sync');

    _isSubscriptionActive = false;
    _reconnectionTimer?.cancel();
    _reconnectionTimer = null;

    await _documentCreateSubscription?.cancel();
    await _documentUpdateSubscription?.cancel();
    await _documentDeleteSubscription?.cancel();

    _documentCreateSubscription = null;
    _documentUpdateSubscription = null;
    _documentDeleteSubscription = null;

    safePrint('Real-time sync stopped');

    // Notify UI of disconnection
    _addSyncEvent(SyncEventNotification(
      type: SyncEventType.connectionClosed,
      message: 'Real-time sync disconnected',
      timestamp: DateTime.now(),
    ));
  }

  /// Start subscription for document creation events
  Future<void> _startDocumentCreateSubscription(String userId) async {
    await _authManager.executeWithTokenRefresh(() async {
      const subscriptionDocument = '''
        subscription OnCreateDocument {
          onCreateDocument {
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
      ''';

      final subscriptionRequest = GraphQLRequest<amplify_doc.Document>(
        document: subscriptionDocument,
        variables: {}, // No variables needed - owner auth handles filtering
        decodePath: 'onCreateDocument',
        modelType: amplify_doc.Document.classType,
      );

      _documentCreateSubscription =
          Amplify.API.subscribe(subscriptionRequest).listen(
        (event) {
          safePrint('Document create subscription event received');
          _handleDocumentCreateEvent(event.data);
        },
        onError: (error) => _handleSubscriptionError(error),
      );

      safePrint('Document create subscription established');
    });
  }

  /// Start subscription for document update events
  Future<void> _startDocumentUpdateSubscription(String userId) async {
    await _authManager.executeWithTokenRefresh(() async {
      const subscriptionDocument = '''
        subscription OnUpdateDocument {
          onUpdateDocument {
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
      ''';

      final subscriptionRequest = GraphQLRequest<amplify_doc.Document>(
        document: subscriptionDocument,
        variables: {}, // No variables needed - owner auth handles filtering
        decodePath: 'onUpdateDocument',
        modelType: amplify_doc.Document.classType,
      );

      _documentUpdateSubscription =
          Amplify.API.subscribe(subscriptionRequest).listen(
        (event) {
          safePrint('Document update subscription event received');
          _handleDocumentUpdateEvent(event.data);
        },
        onError: (error) => _handleSubscriptionError(error),
      );

      safePrint('Document update subscription established');
    });
  }

  /// Start subscription for document deletion events
  Future<void> _startDocumentDeleteSubscription(String userId) async {
    await _authManager.executeWithTokenRefresh(() async {
      const subscriptionDocument = '''
        subscription OnDeleteDocument {
          onDeleteDocument {
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
      ''';

      final subscriptionRequest = GraphQLRequest<amplify_doc.Document>(
        document: subscriptionDocument,
        variables: {}, // No variables needed - owner auth handles filtering
        decodePath: 'onDeleteDocument',
        modelType: amplify_doc.Document.classType,
      );

      _documentDeleteSubscription =
          Amplify.API.subscribe(subscriptionRequest).listen(
        (event) {
          safePrint('Document delete subscription event received');
          _handleDocumentDeleteEvent(event.data);
        },
        onError: (error) => _handleSubscriptionError(error),
      );

      safePrint('Document delete subscription established');
    });
  }

  /// Handle document creation events from subscription
  void _handleDocumentCreateEvent(amplify_doc.Document? document) async {
    if (document == null) return;

    try {
      safePrint('Received document create event: ${document.syncId}');

      // Update local database
      await _updateLocalDocument(document);

      // Notify UI
      final notification = SyncEventNotification(
        type: SyncEventType.documentCreated,
        documentId: document.syncId,
        message: 'Document "${document.title}" created on another device',
        timestamp: DateTime.now(),
      );

      _addSyncEvent(notification);
    } catch (e) {
      safePrint('Error handling document create event: $e');
      _addSyncEvent(SyncEventNotification(
        type: SyncEventType.error,
        message: 'Failed to process document creation: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Handle document update events from subscription
  void _handleDocumentUpdateEvent(amplify_doc.Document? document) async {
    if (document == null) return;

    try {
      safePrint('Received document update event: ${document.syncId}');

      // Check for conflicts with local version
      final localDoc = await _getLocalDocument(document.syncId);
      if (localDoc != null) {
        // For now, always accept remote changes
        // TODO: Implement proper version conflict detection when local documents have version field
        safePrint('Local document exists, updating with remote version');
      }

      // Update local database
      await _updateLocalDocument(document);

      // Notify UI
      final notification = SyncEventNotification(
        type: SyncEventType.documentUpdated,
        documentId: document.syncId,
        message: 'Document "${document.title}" updated on another device',
        timestamp: DateTime.now(),
      );

      _addSyncEvent(notification);
    } catch (e) {
      safePrint('Error handling document update event: $e');
      _addSyncEvent(SyncEventNotification(
        type: SyncEventType.error,
        message: 'Failed to process document update: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Handle document deletion events from subscription
  void _handleDocumentDeleteEvent(amplify_doc.Document? document) async {
    if (document == null) return;

    try {
      safePrint('Received document delete event: ${document.syncId}');

      // Update local database (soft delete)
      await _updateLocalDocument(document);

      // Notify UI
      final notification = SyncEventNotification(
        type: SyncEventType.documentDeleted,
        documentId: document.syncId,
        message: 'Document "${document.title}" deleted on another device',
        timestamp: DateTime.now(),
      );

      _addSyncEvent(notification);
    } catch (e) {
      safePrint('Error handling document delete event: $e');
      _addSyncEvent(SyncEventNotification(
        type: SyncEventType.error,
        message: 'Failed to process document deletion: $e',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Update local database with remote document changes
  Future<void> _updateLocalDocument(amplify_doc.Document amplifyDoc) async {
    // Convert Amplify Document to local Document format
    final localDocument = _convertAmplifyToLocalDocument(amplifyDoc);

    // Check if document exists locally
    final existingDoc =
        await _documentRepository.getDocument(amplifyDoc.syncId);

    if (existingDoc != null) {
      // Update existing document
      await _documentRepository.updateDocument(localDocument);
    } else {
      // Create new document
      await _documentRepository.insertRemoteDocument(localDocument);
    }

    // Sync file attachments
    await _syncFileAttachments(amplifyDoc);
  }

  /// Sync file attachments from remote document
  Future<void> _syncFileAttachments(amplify_doc.Document amplifyDoc) async {
    final fileAttachments = amplifyDoc.fileAttachments;
    if (fileAttachments == null || fileAttachments.isEmpty) {
      safePrint(
          'No file attachments to sync for document: ${amplifyDoc.syncId}');
      return;
    }

    try {
      // Get existing file attachments
      final existingFiles =
          await _documentRepository.getFileAttachments(amplifyDoc.syncId);
      final existingFileNames = existingFiles.map((f) => f.fileName).toSet();

      safePrint(
          'Syncing ${fileAttachments.length} file attachments for document: ${amplifyDoc.syncId}');

      // Add or update file attachments from remote
      for (final remoteFile in fileAttachments) {
        if (existingFileNames.contains(remoteFile.fileName)) {
          // Update existing file attachment (S3 key, etc.)
          safePrint(
              'Updating existing file attachment: ${remoteFile.fileName}');

          await _documentRepository.updateFileS3Key(
            syncId: amplifyDoc.syncId,
            fileName: remoteFile.fileName,
            s3Key: remoteFile.s3Key,
          );

          // Update label if present
          if (remoteFile.label != null) {
            await _documentRepository.updateFileLabel(
              syncId: amplifyDoc.syncId,
              fileName: remoteFile.fileName,
              label: remoteFile.label,
            );
          }

          // Don't update localPath from remote - filePath is the S3 path, not local
        } else {
          // Add new file attachment
          safePrint('Adding new file attachment: ${remoteFile.fileName}');

          await _documentRepository.addFileAttachment(
            syncId: amplifyDoc.syncId,
            fileName: remoteFile.fileName,
            label: remoteFile.label,
            s3Key: remoteFile.s3Key,
            fileSize: remoteFile.fileSize,
            localPath: null, // File not downloaded yet
          );
        }
      }

      // Remove file attachments that no longer exist remotely
      final remoteFileNames = fileAttachments.map((f) => f.fileName).toSet();
      for (final existingFile in existingFiles) {
        if (!remoteFileNames.contains(existingFile.fileName)) {
          safePrint(
              'Removing file attachment no longer in remote: ${existingFile.fileName}');

          await _documentRepository.deleteFileAttachment(
            syncId: amplifyDoc.syncId,
            fileName: existingFile.fileName,
          );
        }
      }

      safePrint(
          'File attachment sync completed for document: ${amplifyDoc.syncId}');
    } catch (e) {
      safePrint('Error syncing file attachments: $e');
      // Don't rethrow - document sync should succeed even if file sync fails
    }
  }

  /// Get local document by ID
  Future<local.Document?> _getLocalDocument(String documentId) async {
    try {
      return await _documentRepository.getDocument(documentId);
    } catch (e) {
      safePrint('Error getting local document: $e');
      return null;
    }
  }

  /// Convert Amplify Document model to local Document model
  local.Document _convertAmplifyToLocalDocument(
      amplify_doc.Document amplifyDoc) {
    return local.Document(
      syncId: amplifyDoc.syncId,
      title: amplifyDoc.title,
      category: _mapCategoryToLocal(amplifyDoc.category),
      date: amplifyDoc.renewalDate?.getDateTimeInUtc(),
      notes: amplifyDoc.notes,
      createdAt: amplifyDoc.createdAt.getDateTimeInUtc(),
      updatedAt: amplifyDoc.lastModified.getDateTimeInUtc(),
      syncState: _mapSyncStateToLocal(amplifyDoc.syncState),
      files: [], // Files handled separately in _syncFileAttachments
    );
  }

  /// Map Amplify category string to local DocumentCategory enum
  local.DocumentCategory _mapCategoryToLocal(String category) {
    switch (category.toLowerCase().replaceAll(' ', '')) {
      case 'carinsurance':
        return local.DocumentCategory.carInsurance;
      case 'homeinsurance':
        return local.DocumentCategory.homeInsurance;
      case 'holiday':
        return local.DocumentCategory.holiday;
      case 'expenses':
        return local.DocumentCategory.expenses;
      default:
        return local.DocumentCategory.other;
    }
  }

  /// Map Amplify sync state string to local SyncState enum
  SyncState _mapSyncStateToLocal(String? syncState) {
    if (syncState == null) return SyncState.synced;

    switch (syncState.toLowerCase()) {
      case 'pendingupload':
        return SyncState.pendingUpload;
      case 'synced':
        return SyncState.synced;
      case 'error':
        return SyncState.error;
      default:
        return SyncState.synced;
    }
  }

  /// Handle subscription errors and implement reconnection logic
  void _handleSubscriptionError(dynamic error) {
    safePrint('Subscription error: $error');

    _isSubscriptionActive = false;

    // Notify UI of error
    _addSyncEvent(SyncEventNotification(
      type: SyncEventType.error,
      message: 'Real-time sync error: $error',
      timestamp: DateTime.now(),
    ));

    // Attempt reconnection with exponential backoff
    if (_reconnectionAttempts < _maxReconnectionAttempts) {
      _scheduleReconnection();
    } else {
      safePrint('Max reconnection attempts reached. Stopping real-time sync.');
      _addSyncEvent(SyncEventNotification(
        type: SyncEventType.connectionFailed,
        message: 'Real-time sync connection failed after multiple attempts',
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnection() {
    _reconnectionAttempts++;
    final delay = Duration(
      seconds:
          _baseReconnectionDelay.inSeconds * (1 << (_reconnectionAttempts - 1)),
    );

    safePrint(
        'Scheduling reconnection attempt $_reconnectionAttempts in ${delay.inSeconds}s');

    _reconnectionTimer = Timer(delay, () async {
      try {
        // Get current user ID dynamically
        final userId = await _authManager.getCurrentUserId();
        if (userId != null) {
          await startRealtimeSync(userId);
        } else {
          safePrint('Cannot reconnect: No authenticated user found');
          _addSyncEvent(SyncEventNotification(
            type: SyncEventType.error,
            message: 'Reconnection failed: User not authenticated',
            timestamp: DateTime.now(),
          ));
        }
      } catch (e) {
        safePrint('Reconnection attempt failed: $e');
        _handleSubscriptionError(e);
      }
    });
  }

  /// Add sync event to stream or background queue
  void _addSyncEvent(SyncEventNotification notification) {
    if (_isAppInBackground) {
      // Queue notification for later processing
      _backgroundNotificationQueue.add(notification);
      safePrint('Queued background notification: ${notification.type}');
    } else {
      // Send notification immediately
      try {
        _syncEventController.add(notification);
      } catch (e) {
        // If controller is closed, recreate it
        if (e
            .toString()
            .contains('Cannot add new events after calling close')) {
          _syncEventController =
              StreamController<SyncEventNotification>.broadcast();
          _syncEventController.add(notification);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Set app background state for notification queuing
  void setAppBackgroundState(bool isInBackground) {
    _isAppInBackground = isInBackground;

    if (!isInBackground && _backgroundNotificationQueue.isNotEmpty) {
      // Process queued notifications
      safePrint(
          'Processing ${_backgroundNotificationQueue.length} queued notifications');

      // Remove duplicates and process
      final uniqueNotifications =
          _deduplicateNotifications(_backgroundNotificationQueue);

      for (final notification in uniqueNotifications) {
        _syncEventController.add(notification);
      }

      _backgroundNotificationQueue.clear();
    }
  }

  /// Remove duplicate notifications from queue
  List<SyncEventNotification> _deduplicateNotifications(
      List<SyncEventNotification> notifications) {
    final Map<String, SyncEventNotification> uniqueNotifications = {};

    for (final notification in notifications) {
      final key = '${notification.type}_${notification.documentId}';

      // Keep the most recent notification for each document/type combination
      if (!uniqueNotifications.containsKey(key) ||
          notification.timestamp.isAfter(uniqueNotifications[key]!.timestamp)) {
        uniqueNotifications[key] = notification;
      }
    }

    return uniqueNotifications.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Monitor subscription health
  void startHealthMonitoring() {
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isSubscriptionActive) {
        safePrint('Subscription health check: Active');

        // Send heartbeat event
        _addSyncEvent(SyncEventNotification(
          type: SyncEventType.heartbeat,
          message: 'Real-time sync is active',
          timestamp: DateTime.now(),
        ));
      } else {
        safePrint('Subscription health check: Inactive');
      }
    });
  }

  /// Handle user sign-out by stopping all real-time sync operations
  /// This should be called when the user signs out
  Future<void> handleSignOut() async {
    safePrint('Handling user sign-out - stopping real-time sync');

    try {
      // Stop all subscriptions
      await stopRealtimeSync();

      // Clear background notification queue
      _backgroundNotificationQueue.clear();

      // Reset connection state
      _reconnectionAttempts = 0;
      _reconnectionTimer?.cancel();
      _reconnectionTimer = null;

      safePrint('Successfully handled sign-out in RealtimeSyncService');
    } catch (e) {
      safePrint('Error handling sign-out in RealtimeSyncService: $e');
      // Don't rethrow - we want sign-out to succeed even if cleanup fails
    }
  }

  /// Dispose of resources
  void dispose() {
    stopRealtimeSync();
    _syncEventController.close();
    _syncEventController = StreamController<SyncEventNotification>.broadcast();
    _reconnectionTimer?.cancel();
  }
}

/// Sync event notification for UI consumption
class SyncEventNotification {
  final SyncEventType type;
  final String? documentId;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? conflictData;

  SyncEventNotification({
    required this.type,
    this.documentId,
    required this.message,
    required this.timestamp,
    this.conflictData,
  });

  @override
  String toString() {
    return 'SyncEventNotification(type: $type, documentId: $documentId, message: $message, timestamp: $timestamp)';
  }
}

/// Types of sync events
enum SyncEventType {
  documentCreated,
  documentUpdated,
  documentDeleted,
  conflictDetected,
  connectionEstablished,
  connectionClosed,
  connectionFailed,
  error,
  heartbeat,
}
