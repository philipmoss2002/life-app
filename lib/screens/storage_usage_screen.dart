import 'package:flutter/material.dart';
import '../services/storage_manager.dart';
import '../services/authentication_service.dart';
import 'subscription_plans_screen.dart';

class StorageUsageScreen extends StatefulWidget {
  const StorageUsageScreen({super.key});

  @override
  State<StorageUsageScreen> createState() => _StorageUsageScreenState();
}

class _StorageUsageScreenState extends State<StorageUsageScreen> {
  final StorageManager _storageManager = StorageManager();
  final AuthenticationService _authService = AuthenticationService();

  StorageInfo? _storageInfo;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
    _listenToStorageUpdates();
  }

  Future<void> _loadStorageInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.getCurrentUser();
      if (user == null) {
        setState(() {
          _errorMessage = 'Please sign in to view storage usage';
          _isLoading = false;
        });
        return;
      }

      final info = await _storageManager.getStorageInfo();
      if (mounted) {
        setState(() {
          _storageInfo = info;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load storage info: $e';
          _isLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Storage Usage'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _handleRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadStorageInfo,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_storageInfo == null) {
      return const Center(
        child: Text('No storage information available'),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildStorageOverviewCard(),
          const SizedBox(height: 16),
          _buildStorageBreakdownCard(),
          const SizedBox(height: 16),
          _buildStorageActionsCard(),
        ],
      ),
    );
  }

  Widget _buildStorageOverviewCard() {
    final info = _storageInfo!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // Visual storage indicator
            _buildStorageIndicator(info),

            const SizedBox(height: 16),

            // Usage text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Used',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  info.usedBytesFormatted,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  info.quotaBytesFormatted,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Available',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  _formatBytes(info.quotaBytes - info.usedBytes),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: info.isOverLimit
                            ? Colors.red
                            : info.isNearLimit
                                ? Colors.orange
                                : Colors.green,
                      ),
                ),
              ],
            ),

            // Warning messages
            if (info.isOverLimit) ...[
              const SizedBox(height: 16),
              _buildWarningBanner(
                'Storage limit exceeded',
                'You cannot upload new files until you free up space or upgrade your plan.',
                Colors.red,
                Icons.error,
              ),
            ] else if (info.isNearLimit) ...[
              const SizedBox(height: 16),
              _buildWarningBanner(
                'Approaching storage limit',
                'You are using ${info.usagePercentage.toStringAsFixed(1)}% of your storage quota.',
                Colors.orange,
                Icons.warning,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStorageIndicator(StorageInfo info) {
    Color indicatorColor;
    if (info.isOverLimit) {
      indicatorColor = Colors.red;
    } else if (info.isNearLimit) {
      indicatorColor = Colors.orange;
    } else {
      indicatorColor = Colors.green;
    }

    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            FractionallySizedBox(
              widthFactor: (info.usagePercentage / 100).clamp(0.0, 1.0),
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${info.usagePercentage.toStringAsFixed(1)}% used',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: indicatorColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner(
      String title, String message, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: color.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageBreakdownCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Storage Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.description,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Documents'),
              subtitle: const Text('Metadata and text content'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Future enhancement: show detailed document breakdown
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Detailed breakdown coming soon'),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.attach_file,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('File Attachments'),
              subtitle: const Text('PDFs, images, and other files'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // Future enhancement: show detailed file breakdown
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Detailed breakdown coming soon'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageActionsCard() {
    final info = _storageInfo!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            if (info.isNearLimit || info.isOverLimit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleUpgrade,
                  icon: const Icon(Icons.upgrade),
                  label: const Text('Upgrade Storage'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            if (info.isNearLimit || info.isOverLimit)
              const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _handleCleanup,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clean Up Storage'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _storageManager.calculateUsage();
    await _loadStorageInfo();
  }

  Future<void> _handleUpgrade() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionPlansScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadStorageInfo();
    }
  }

  Future<void> _handleCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Up Storage'),
        content: const Text(
          'This will remove orphaned files that are no longer associated with any documents. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clean Up'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Show loading dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Cleaning up...'),
                ],
              ),
            ),
          );
        }

        await _storageManager.cleanupDeletedFiles();

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage cleanup completed'),
              backgroundColor: Colors.green,
            ),
          );
          await _loadStorageInfo();
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleanup failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
