import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_sync_service.dart';

/// Screen for managing sync settings
/// Allows users to control when and how synchronization occurs
class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final CloudSyncService _syncService = CloudSyncService();

  bool _wifiOnlySync = false;
  bool _syncPaused = false;
  bool _isLoading = true;
  int _estimatedDataUsage = 0; // in MB

  static const _wifiOnlyKey = 'sync_wifi_only';
  static const _syncPausedKey = 'sync_paused';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final syncStatus = await _syncService.getSyncStatus();

      if (mounted) {
        setState(() {
          _wifiOnlySync = prefs.getBool(_wifiOnlyKey) ?? false;
          _syncPaused = prefs.getBool(_syncPausedKey) ?? false;
          _estimatedDataUsage = _calculateEstimatedDataUsage(syncStatus);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _calculateEstimatedDataUsage(SyncStatus status) {
    // Estimate data usage based on pending changes
    // Assume average document is 50KB and average file is 2MB
    final documentSize = 0.05; // MB
    final fileSize = 2.0; // MB
    final pendingChanges = status.pendingChanges;

    // Rough estimate: 30% documents only, 70% with files
    final estimatedMB = (pendingChanges * 0.3 * documentSize) +
        (pendingChanges * 0.7 * fileSize);

    return estimatedMB.ceil();
  }

  Future<void> _toggleWifiOnly(bool value) async {
    if (value && !_wifiOnlySync) {
      // Enabling Wi-Fi only mode
      final confirmed = await _showWifiOnlyConfirmation();
      if (!confirmed) return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);

    if (mounted) {
      setState(() {
        _wifiOnlySync = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Sync will only occur on Wi-Fi'
                : 'Sync will occur on Wi-Fi and cellular',
          ),
        ),
      );
    }
  }

  Future<bool> _showWifiOnlyConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Wi-Fi Only Sync?'),
        content: const Text(
          'When enabled, documents and files will only sync when connected to Wi-Fi. '
          'This helps avoid cellular data charges but may delay synchronization.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _togglePauseSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_syncPausedKey, value);

    if (value) {
      await _syncService.stopSync();
    } else {
      await _syncService.startSync();
    }

    if (mounted) {
      setState(() {
        _syncPaused = value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value ? 'Sync paused - changes will queue locally' : 'Sync resumed',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildSyncControlSection(),
                const Divider(),
                _buildDataUsageSection(),
                const Divider(),
                _buildInfoSection(),
              ],
            ),
    );
  }

  Widget _buildSyncControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sync Control',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        SwitchListTile(
          secondary: Icon(
            _syncPaused ? Icons.pause_circle : Icons.sync,
            color: _syncPaused ? Colors.orange : Colors.green,
          ),
          title: const Text('Pause Sync'),
          subtitle: Text(
            _syncPaused
                ? 'Sync is paused - changes will queue locally'
                : 'Sync is active',
          ),
          value: _syncPaused,
          onChanged: _togglePauseSync,
        ),
        SwitchListTile(
          secondary: Icon(
            Icons.wifi,
            color: _wifiOnlySync ? Colors.blue : Colors.grey,
          ),
          title: const Text('Wi-Fi Only Sync'),
          subtitle: Text(
            _wifiOnlySync
                ? 'Sync only when connected to Wi-Fi'
                : 'Sync on Wi-Fi and cellular',
          ),
          value: _wifiOnlySync,
          onChanged: _syncPaused ? null : _toggleWifiOnly,
        ),
        if (_wifiOnlySync)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sync will wait for Wi-Fi connection',
                      style: TextStyle(
                        color: Colors.blue[900],
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (!_wifiOnlySync && !_syncPaused)
          ListTile(
            leading: Icon(Icons.warning_amber, color: Colors.orange[700]),
            title: const Text('Cellular Data Warning'),
            subtitle: const Text('Syncing on cellular may incur data charges'),
            trailing: TextButton(
              onPressed: () => _toggleWifiOnly(true),
              child: const Text('Use Wi-Fi Only'),
            ),
          ),
      ],
    );
  }

  Widget _buildDataUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Data Usage',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.data_usage),
          title: const Text('Estimated Data Usage'),
          subtitle: Text(
            _estimatedDataUsage > 0
                ? 'Approximately $_estimatedDataUsage MB pending'
                : 'No pending changes',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _estimatedDataUsage > 100
                  ? Colors.red[100]
                  : _estimatedDataUsage > 50
                      ? Colors.orange[100]
                      : Colors.green[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_estimatedDataUsage MB',
              style: TextStyle(
                color: _estimatedDataUsage > 100
                    ? Colors.red[700]
                    : _estimatedDataUsage > 50
                        ? Colors.orange[700]
                        : Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            'This is an estimate based on pending changes. Actual usage may vary.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'About Sync',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        const ListTile(
          leading: Icon(Icons.help_outline),
          title: Text('How Sync Works'),
          subtitle: Text(
            'Your documents sync automatically every 30 seconds when online. '
            'Changes made offline will sync when connection is restored.',
          ),
        ),
        const ListTile(
          leading: Icon(Icons.security),
          title: Text('Security'),
          subtitle: Text(
            'All data is encrypted in transit (TLS 1.3) and at rest (AES-256).',
          ),
        ),
      ],
    );
  }
}
