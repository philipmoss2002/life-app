import 'dart:async';
import 'package:flutter/material.dart';
import '../models/new_document.dart';
import '../models/sync_state.dart';
import '../repositories/document_repository.dart';
import '../services/authentication_service.dart';
import '../services/sync_service.dart';
import '../services/subscription_status_notifier.dart';
import '../services/subscription_service.dart';
import 'sign_in_screen.dart';
import 'new_settings_screen.dart';
import 'new_document_detail_screen.dart';

/// Main document list screen for the rewritten app
class NewDocumentListScreen extends StatefulWidget {
  const NewDocumentListScreen({super.key});

  @override
  State<NewDocumentListScreen> createState() => _NewDocumentListScreenState();
}

class _NewDocumentListScreenState extends State<NewDocumentListScreen> {
  final _documentRepository = DocumentRepository();
  final _authService = AuthenticationService();
  final _syncService = SyncService();
  late final SubscriptionStatusNotifier _subscriptionNotifier;

  List<Document> _documents = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  SyncStatus _syncStatus = SyncStatus.idle;

  @override
  void initState() {
    super.initState();
    _subscriptionNotifier = SubscriptionStatusNotifier(SubscriptionService());
    // Initialize subscription notifier in background (non-blocking)
    _initializeSubscriptionNotifier();
    // Load documents immediately (don't wait for subscription)
    _checkAuthAndLoadDocuments();
    _listenToSyncStatus();
  }

  Future<void> _initializeSubscriptionNotifier() async {
    try {
      // Initialize with timeout to prevent blocking UI
      await _subscriptionNotifier.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint(
              'Subscription initialization timed out - continuing without subscription');
          throw TimeoutException('Subscription initialization timed out');
        },
      );
      _subscriptionNotifier.addListener(_onSubscriptionStatusChanged);
      // Trigger rebuild after subscription is initialized
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to initialize subscription notifier: $e');
      // Continue anyway - app should work without subscription
    }
  }

  void _onSubscriptionStatusChanged() {
    if (mounted) {
      setState(() {
        // Trigger rebuild when subscription status changes
      });
    }
  }

  @override
  void dispose() {
    _subscriptionNotifier.removeListener(_onSubscriptionStatusChanged);
    _subscriptionNotifier.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadDocuments() async {
    // Check authentication
    _isAuthenticated = await _authService.isAuthenticated();

    // Load documents
    await _loadDocuments();
  }

  void _listenToSyncStatus() {
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });

        // Reload documents when sync completes
        if (status == SyncStatus.completed) {
          _loadDocuments();
        }
      }
    });
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final docs = await _documentRepository.getAllDocuments();
      if (mounted) {
        setState(() {
          _documents = docs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to sync your documents'),
        ),
      );
      return;
    }

    try {
      await _syncService.performSync();
      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSignIn() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );

    if (result == true) {
      await _checkAuthAndLoadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Sync status indicator
          if (_isAuthenticated)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                child: _buildSyncStatusChip(),
              ),
            ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NewSettingsScreen(),
                ),
              );
              // Reload if user signed out
              if (result == true) {
                await _checkAuthAndLoadDocuments();
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleCreateDocument,
        tooltip: 'Create Document',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSyncStatusChip() {
    IconData icon;
    Color color;
    String label;

    switch (_syncStatus) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = Colors.blue;
        label = 'Syncing';
        break;
      case SyncStatus.completed:
        icon = Icons.cloud_done;
        color = Colors.purple;
        label = 'Synced';
        break;
      case SyncStatus.error:
        icon = Icons.error;
        color = Colors.red;
        label = 'Error';
        break;
      case SyncStatus.idle:
        icon = Icons.cloud_done;
        color = Colors.grey;
        label = 'Idle';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_syncStatus == SyncStatus.syncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          else
            Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_isAuthenticated) {
      return _buildSignInPrompt();
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_documents.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        itemCount: _documents.length,
        itemBuilder: (context, index) {
          final doc = _documents[index];
          return _buildDocumentCard(doc);
        },
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Sign In to Sync',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to sync your documents across devices and access them anywhere',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _handleSignIn,
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // User can still use the app without signing in
                // Just show empty state
                setState(() {
                  _isAuthenticated = false;
                });
              },
              child: const Text('Continue without account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first document',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(Document doc) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getCategoryIcon(doc.category),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(doc.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSubscriptionBadge(),
          ],
        ),
        onTap: () => _handleDocumentTap(doc),
      ),
    );
  }

  Widget _buildSubscriptionBadge() {
    if (!_isAuthenticated) {
      return const SizedBox.shrink();
    }

    final isCloudSyncEnabled = _subscriptionNotifier.isCloudSyncEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCloudSyncEnabled
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCloudSyncEnabled
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCloudSyncEnabled ? Icons.cloud_done : Icons.cloud_off,
            size: 12,
            color: isCloudSyncEnabled ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isCloudSyncEnabled ? 'Cloud Synced' : 'Device Only',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isCloudSyncEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSyncIndicator(SyncState syncState) {
    IconData icon;
    Color color;
    String tooltip;

    ///This is the cloud icon on the list entry
    switch (syncState) {
      case SyncState.synced:
        icon = Icons.cloud_done;
        color = Colors.green;
        tooltip = 'Synced';
        break;
      case SyncState.pendingUpload:
        icon = Icons.cloud_upload;
        color = Colors.orange;
        tooltip = 'Pending upload';
        break;
      case SyncState.pendingDownload:
        icon = Icons.cloud_download;
        color = Colors.blue;
        tooltip = 'Pending download';
        break;
      case SyncState.uploading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
          ),
        );
      case SyncState.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green[700]!),
          ),
        );
      case SyncState.error:
        icon = Icons.error;
        color = Colors.red;
        tooltip = 'Sync error';
        break;
      case SyncState.localOnly:
        icon = Icons.cloud_off;
        color = Colors.grey;
        tooltip = 'Saved Locally';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 20, color: color),
    );
  }

  /// Get icon based on document category
  IconData _getCategoryIcon(DocumentCategory category) {
    switch (category) {
      case DocumentCategory.homeInsurance:
        return Icons.home;
      case DocumentCategory.carInsurance:
        return Icons.directions_car;
      case DocumentCategory.holiday:
        return Icons.flight;
      case DocumentCategory.expenses:
        return Icons.receipt;
      case DocumentCategory.other:
        return Icons.description;
    }
  }

  void _handleDocumentTap(Document doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewDocumentDetailScreen(document: doc),
      ),
    ).then((result) {
      // Reload documents if changes were made
      if (result == true) {
        _loadDocuments();
      }
    });
  }

  void _handleCreateDocument() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewDocumentDetailScreen(document: null),
      ),
    ).then((result) {
      // Reload documents if a new document was created
      if (result == true) {
        _loadDocuments();
      }
    });
  }
}
