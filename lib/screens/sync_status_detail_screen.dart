import 'package:flutter/material.dart';
import '../models/document.dart';
import '../models/sync_state.dart';
import '../services/cloud_sync_service.dart';

/// Screen showing detailed sync status for a document
class SyncStatusDetailScreen extends StatefulWidget {
  final Document document;

  const SyncStatusDetailScreen({
    super.key,
    required this.document,
  });

  @override
  State<SyncStatusDetailScreen> createState() => _SyncStatusDetailScreenState();
}

class _SyncStatusDetailScreenState extends State<SyncStatusDetailScreen> {
  final CloudSyncService _syncService = CloudSyncService();
  SyncStatus? _syncStatus;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    setState(() => _isLoading = true);
    try {
      final status = await _syncService.getSyncStatus();
      setState(() {
        _syncStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _retrySync() async {
    setState(() => _isLoading = true);
    try {
      await _syncService.queueDocumentSync(
        widget.document,
        SyncOperationType.update,
      );
      await _loadSyncStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync retry queued')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retry sync: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Status'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDocumentInfo(),
                  const SizedBox(height: 24),
                  _buildSyncStateCard(),
                  const SizedBox(height: 16),
                  _buildSyncDetailsCard(),
                  const SizedBox(height: 16),
                  if (widget.document.syncState == SyncState.error)
                    _buildErrorCard(),
                  if (widget.document.syncState == SyncState.error ||
                      widget.document.syncState == SyncState.pending)
                    _buildRetryButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.document.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.document.category,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStateCard() {
    final syncState = widget.document.syncState;
    final stateInfo = _getSyncStateInfo(syncState);

    return Card(
      color: stateInfo['color'] as Color?,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              stateInfo['icon'] as IconData,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sync Status',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stateInfo['label'] as String,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Last Modified',
              _formatDateTime(widget.document.lastModified),
            ),
            const Divider(),
            _buildDetailRow(
              'Version',
              widget.document.version.toString(),
            ),
            const Divider(),
            _buildDetailRow(
              'Last Sync',
              _syncStatus?.lastSyncTime != null
                  ? _formatDateTime(_syncStatus!.lastSyncTime!)
                  : 'Never',
            ),
            const Divider(),
            _buildDetailRow(
              'Pending Changes',
              _syncStatus?.pendingChanges.toString() ?? '0',
            ),
            const Divider(),
            _buildDetailRow(
              'File Attachments',
              widget.document.filePaths.length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text(
                  'Sync Error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'An error occurred while syncing this document. Please try again.',
              style: TextStyle(color: Colors.red[900]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _retrySync,
        icon: const Icon(Icons.refresh),
        label: const Text('Retry Sync'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getSyncStateInfo(SyncState state) {
    switch (state) {
      case SyncState.synced:
        return {
          'icon': Icons.cloud_done,
          'label': 'Synced',
          'color': Colors.green,
        };
      case SyncState.pending:
        return {
          'icon': Icons.cloud_upload,
          'label': 'Pending',
          'color': Colors.orange,
        };
      case SyncState.syncing:
        return {
          'icon': Icons.cloud_sync,
          'label': 'Syncing',
          'color': Colors.blue,
        };
      case SyncState.conflict:
        return {
          'icon': Icons.warning,
          'label': 'Conflict',
          'color': Colors.red,
        };
      case SyncState.error:
        return {
          'icon': Icons.error,
          'label': 'Error',
          'color': Colors.red,
        };
      case SyncState.notSynced:
        return {
          'icon': Icons.cloud_off,
          'label': 'Not Synced',
          'color': Colors.grey,
        };
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
