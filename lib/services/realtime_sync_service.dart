import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../models/Document.dart';
import 'database_service.dart';
import 'auth_token_manager.dart';

/// Service responsible for real-time synchronization using GraphQL subscriptions
/// Handles subscription setup, event processing, and local database updates
class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  // Subscription management
  StreamSubscription<GraphQLResponse<Document>>? _documentCreateSubscription;
  StreamSubscription<GraphQLResponse<Document>>? _documentUpdateSubscription;
  StreamSubscription<GraphQLResponse<Document>>? _documentDeleteSubscription;

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
  final DatabaseService _databaseService = DatabaseService.instance;
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
        subscription OnCreateDocument(\$userId: String!) {
          onCreateDocument(filter: {userId: {eq: \$userId}}) {
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

      final subscriptionRequest = GraphQLRequest<Document>(
        document: subscriptionDocument,
        variables: {'userId': userId},
        decodePath: 'onCreateDocument',
        modelType: Document.classType,
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
        subscription OnUpdateDocument(\$userId: String!) {
          onUpdateDocument(filter: {userId: {eq: \$userId}}) {
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

      final subscriptionRequest = GraphQLRequest<Document>(
        document: subscriptionDocument,
        variables: {'userId': userId},
        decodePath: 'onUpdateDocument',
        modelType: Document.classType,
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
        subscription OnDeleteDocument(\$userId: String!) {
          onDeleteDocument(filter: {userId: {eq: \$userId}}) {
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

      final subscriptionRequest = GraphQLRequest<Document>(
        document: subscriptionDocument,
        variables: {'userId': userId},
        decodePath: 'onDeleteDocument',
        modelType: Document.classType,
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
  void _handleDocumentCreateEvent(Document? document) async {
    if (document == null) return;

    try {
      safePrint('Received document create event: ${document.id}');

      // Update local database
      await _updateLocalDocument(document);

      // Notify UI
      final notification = SyncEventNotification(
        type: SyncEventType.documentCreated,
        documentId: document.id,
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
  void _handleDocumentUpdateEvent(Document? document) async {
    if (document == null) return;

    try {
      safePrint('Received document update event: ${document.id}');

      // Check for conflicts with local version
      final localDoc = await _getLocalDocument(document.id);
      if (localDoc != null && localDoc.version >= document.version) {
        // Local version is newer or same - potential conflict
        _handleVersionConflict(localDoc, document);
        return;
      }

      // Update local database
      await _updateLocalDocument(document);

      // Notify UI
      final notification = SyncEventNotification(
        type: SyncEventType.documentUpdated,
        documentId: document.id,
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
  void _handleDocumentDeleteEvent(Document? document) async {
    if (document == null) return;

    try {
      safePrint('Received document delete event: ${document.id}');

      // Update local database (soft delete)
      await _updateLocalDocument(document);

      // Notify UI
      final notification = SyncEventNotification(
        type: SyncEventType.documentDeleted,
        documentId: document.id,
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
  Future<void> _updateLocalDocument(Document document) async {
    // Convert Amplify Document to local Document format
    final localDocument = _convertAmplifyToLocalDocument(document);

    // Check if document exists locally
    final existingDoc = await _getLocalDocument(document.id);

    if (existingDoc != null) {
      // Update existing document
      await _databaseService.updateDocument(localDocument);
    } else {
      // Create new document
      await _databaseService.createDocument(localDocument);
    }
  }

  /// Get local document by ID
  Future<Document?> _getLocalDocument(String documentId) async {
    try {
      final allDocs = await _databaseService.getAllDocuments();
      for (final doc in allDocs) {
        if (doc.id == documentId) {
          return doc;
        }
      }
      return null;
    } catch (e) {
      safePrint('Error getting local document: $e');
      return null;
    }
  }

  /// Convert Amplify Document model to local Document model
  Document _convertAmplifyToLocalDocument(Document amplifyDoc) {
    // Convert Amplify Document to local Document format using DocumentExtensions
    // This ensures compatibility with DatabaseService which expects Document objects
    return Document(
      id: amplifyDoc.id,
      userId: amplifyDoc.userId,
      title: amplifyDoc.title,
      category: amplifyDoc.category,
      filePaths: amplifyDoc.filePaths,
      renewalDate: amplifyDoc.renewalDate,
      notes: amplifyDoc.notes,
      createdAt: amplifyDoc.createdAt,
      lastModified: amplifyDoc.lastModified,
      version: amplifyDoc.version,
      syncState: amplifyDoc.syncState,
      conflictId: amplifyDoc.conflictId,
      deleted: amplifyDoc.deleted,
      deletedAt: amplifyDoc.deletedAt,
    );
  }

  /// Handle version conflicts between local and remote documents
  void _handleVersionConflict(Document localDoc, Document remoteDoc) {
    safePrint('Version conflict detected for document: ${remoteDoc.id}');

    final notification = SyncEventNotification(
      type: SyncEventType.conflictDetected,
      documentId: remoteDoc.id,
      message: 'Conflict detected for document "${remoteDoc.title}"',
      timestamp: DateTime.now(),
      conflictData: {
        'localVersion': localDoc.version,
        'remoteVersion': remoteDoc.version,
        'localTitle': localDoc.title,
        'remoteTitle': remoteDoc.title,
      },
    );

    _addSyncEvent(notification);
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
