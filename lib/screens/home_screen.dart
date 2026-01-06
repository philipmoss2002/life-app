import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/Document.dart';
import '../models/sync_state.dart';

import '../models/model_extensions.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';
import '../services/conflict_resolution_service.dart';
import '../services/storage_manager.dart';
import '../providers/auth_provider.dart';
import '../widgets/subscription_prompt.dart';
import 'add_document_screen.dart';
import 'document_detail_screen.dart';
import 'upcoming_renewals_screen.dart';
import 'settings_screen.dart';
import 'sync_status_detail_screen.dart';
import 'conflict_resolution_screen.dart';
import 'storage_usage_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SubscriptionStateMixin {
  final List<String> categories = [
    'All',
    'Home Insurance',
    'Car Insurance',
    'Mortgage',
    'Holiday',
    'Other',
  ];
  final StorageManager _storageManager = StorageManager();
  String selectedCategory = 'All';
  List<Document> documents = [];
  bool isLoading = true;
  StorageInfo? _storageInfo;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    _loadStorageInfo();
    _listenToStorageUpdates();
  }

  Future<void> _loadStorageInfo() async {
    try {
      final info = await _storageManager.getStorageInfo();
      if (mounted) {
        setState(() {
          _storageInfo = info;
        });
      }
    } catch (e) {
      // Silently fail - storage info is not critical
    }
  }

  void _listenToStorageUpdates() {
    _storageManager.storageUpdates.listen((info) {
      if (mounted) {
        setState(() {
          _storageInfo = info;
        });
      }
    });
  }

  int get _conflictCount {
    return documents
        .where((doc) => doc.syncState == SyncState.conflict.toJson())
        .length;
  }

  Future<void> _loadDocuments() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    // Get current user from auth provider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      // User not authenticated, show empty list
      setState(() {
        documents = [];
        isLoading = false;
      });
      return;
    }

    // Load documents for the current user only
    final docs = selectedCategory == 'All'
        ? await DatabaseService.instance.getUserDocuments(currentUser.id)
        : await DatabaseService.instance
            .getUserDocumentsByCategory(currentUser.id, selectedCategory);

    if (!mounted) return;
    setState(() {
      documents = docs;
      isLoading = false;
    });
  }

  Future<void> _handleSubscriptionBannerTap() async {
    if (subscriptionStatus == SubscriptionStatus.none) {
      await SubscriptionPrompt.navigateToPlans(context);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SettingsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Reminders'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Upcoming Reminders',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UpcomingRenewalsScreen(),
                ),
              );
              _loadDocuments();
            },
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return IconButton(
                icon: Icon(
                  authProvider.isAuthenticated
                      ? Icons.cloud_done
                      : Icons.cloud_off,
                ),
                tooltip: authProvider.isAuthenticated
                    ? 'Cloud Sync Active'
                    : 'Cloud Sync Disabled',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  _loadDocuments();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              _loadDocuments();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isAuthenticated) {
                return SubscriptionPrompt.buildSubscriptionBanner(
                  context,
                  subscriptionStatus,
                  () => _handleSubscriptionBannerTap(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _buildStorageWarningBanner(),
          _buildConflictBanner(),
          _buildUpcomingRenewalsBanner(),
          _buildCategoryFilter(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : documents.isEmpty
                    ? _buildEmptyState()
                    : _buildDocumentList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddDocumentScreen()),
          );
          _loadDocuments();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStorageWarningBanner() {
    if (_storageInfo == null) return const SizedBox.shrink();
    if (!_storageInfo!.isNearLimit && !_storageInfo!.isOverLimit) {
      return const SizedBox.shrink();
    }

    final isOverLimit = _storageInfo!.isOverLimit;
    final color = isOverLimit ? Colors.red : Colors.orange;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StorageUsageScreen(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color[300]!, width: 2),
        ),
        child: Row(
          children: [
            Icon(
              isOverLimit ? Icons.error : Icons.warning_amber_rounded,
              color: color[800],
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOverLimit
                        ? 'Storage Limit Exceeded'
                        : 'Storage Almost Full',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color[900],
                    ),
                  ),
                  Text(
                    '${_storageInfo!.usagePercentage.toStringAsFixed(1)}% used (${_storageInfo!.usedBytesFormatted} / ${_storageInfo!.quotaBytesFormatted})',
                    style: TextStyle(color: color[800]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOverLimit
                        ? 'Cannot upload new files'
                        : 'Tap to manage storage',
                    style: TextStyle(
                      color: color[700],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color[800]),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictBanner() {
    if (_conflictCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[300]!, width: 2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red[800], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Conflicts Detected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red[900],
                  ),
                ),
                Text(
                  '$_conflictCount ${_conflictCount == 1 ? 'document has' : 'documents have'} conflicting changes',
                  style: TextStyle(color: Colors.red[800]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap on documents below to resolve',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.red[800]),
        ],
      ),
    );
  }

  Widget _buildUpcomingRenewalsBanner() {
    final upcomingCount = documents.where((doc) {
      if (doc.renewalDate == null) return false;
      final daysUntil = doc.renewalDate!.difference(DateTime.now()).inDays;
      return daysUntil >= 0 && daysUntil <= 30;
    }).length;

    if (upcomingCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UpcomingRenewalsScreen(),
          ),
        );
        _loadDocuments();
      },
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange[800], size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upcoming Reminders',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange[900],
                    ),
                  ),
                  Text(
                    '$upcomingCount ${upcomingCount == 1 ? 'document' : 'documents'} due within 30 days',
                    style: TextStyle(color: Colors.orange[800]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.orange[800]),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => selectedCategory = category);
                _loadDocuments();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first document',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final hasConflict = doc.syncState == SyncState.conflict.toJson();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Stack(
            children: [
              ListTile(
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.category),
                    if (doc.renewalDate != null)
                      Text(
                        '${_getDateLabel(doc.category)}: ${_formatDate(doc.renewalDateTime!)}',
                        style: TextStyle(
                          color: _isRenewalSoon(doc.renewalDateTime!)
                              ? Colors.red
                              : null,
                        ),
                      ),
                    if (hasConflict)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Sync conflict - tap to resolve',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildSyncStatusIndicator(doc),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () async {
                  // If document has a conflict, go directly to conflict resolution
                  if (hasConflict) {
                    await _handleConflictResolution(doc);
                  } else {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DocumentDetailScreen(document: doc),
                      ),
                    );
                  }
                  _loadDocuments();
                },
              ),
              // Conflict badge overlay
              if (hasConflict)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.white,
                          size: 14,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'CONFLICT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSyncStatusIndicator(Document doc) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Only show sync indicators if user is authenticated
        if (!authProvider.isAuthenticated) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => _showSyncStatusDetail(doc),
          child: _getSyncStatusIcon(doc.syncStateEnum),
        );
      },
    );
  }

  Widget _getSyncStatusIcon(SyncState syncState) {
    switch (syncState) {
      case SyncState.synced:
        return const Icon(
          Icons.cloud_done,
          color: Colors.green,
          size: 20,
        );
      case SyncState.pending:
        return const Icon(
          Icons.cloud_upload,
          color: Colors.orange,
          size: 20,
        );
      case SyncState.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
        );
      case SyncState.conflict:
        return const Icon(
          Icons.warning,
          color: Colors.red,
          size: 20,
        );
      case SyncState.error:
        return const Icon(
          Icons.error,
          color: Colors.red,
          size: 20,
        );
      case SyncState.notSynced:
        return const Icon(
          Icons.cloud_off,
          color: Colors.grey,
          size: 20,
        );
      case SyncState.pendingDeletion:
        return const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 20,
        );
    }
  }

  Future<void> _showSyncStatusDetail(Document doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SyncStatusDetailScreen(document: doc),
      ),
    );
    _loadDocuments();
  }

  Future<void> _handleConflictResolution(Document doc) async {
    // Get the conflict for this document
    final conflictService = ConflictResolutionService();
    final conflicts = await conflictService.getActiveConflicts();

    final conflict = conflicts.firstWhere(
      (c) => c.documentId == doc.syncId.toString(),
      orElse: () {
        // If no conflict found in service, create a mock one for UI purposes
        // In real scenario, this should be fetched from the sync service
        return DocumentConflict(
          id: 'conflict_${DateTime.now().millisecondsSinceEpoch}',
          documentId: doc.syncId.toString(),
          localDocument: doc,
          remoteDocument: doc, // This should come from remote
          type: ConflictType.concurrentModification,
          detectedAt: DateTime.now(),
        );
      },
    );

    final result = await Navigator.push<Document>(
      context,
      MaterialPageRoute(
        builder: (context) => ConflictResolutionScreen(conflict: conflict),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conflict resolved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Home Insurance':
        return Icons.home;
      case 'Car Insurance':
        return Icons.directions_car;
      case 'Mortgage':
        return Icons.account_balance;
      case 'Holiday':
        return Icons.flight_takeoff;
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isRenewalSoon(DateTime renewalDate) {
    final daysUntilRenewal = renewalDate.difference(DateTime.now()).inDays;
    return daysUntilRenewal <= 30 && daysUntilRenewal >= 0;
  }

  String _getDateLabel(String category) {
    switch (category) {
      case 'Holiday':
        return 'Payment Due';
      case 'Other':
        return 'Date';
      default:
        return 'Renewal';
    }
  }
}
