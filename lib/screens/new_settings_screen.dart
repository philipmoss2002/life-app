import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/authentication_service.dart';
import '../services/subscription_service.dart';
import '../services/subscription_status_notifier.dart';
import '../models/auth_state.dart';
import 'new_logs_viewer_screen.dart';
import 'subscription_status_screen.dart';

/// Clean settings screen without test features
///
/// Displays only production-ready functionality:
/// - Account information (user email)
/// - App version
/// - View Logs button
/// - Sign Out button
class NewSettingsScreen extends StatefulWidget {
  const NewSettingsScreen({super.key});

  @override
  State<NewSettingsScreen> createState() => _NewSettingsScreenState();
}

class _NewSettingsScreenState extends State<NewSettingsScreen> {
  final _authService = AuthenticationService();
  final _subscriptionService = SubscriptionService();
  late final SubscriptionStatusNotifier _statusNotifier;

  AuthState? _authState;
  PackageInfo? _packageInfo;
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.none;
  bool _isLoading = true;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _statusNotifier = SubscriptionStatusNotifier(_subscriptionService);
    _initializeNotifier();
    _loadData();
  }

  Future<void> _initializeNotifier() async {
    try {
      await _statusNotifier.initialize();
      _statusNotifier.addListener(_onSubscriptionStatusChanged);
    } catch (e) {
      // Error already logged by notifier
    }
  }

  void _onSubscriptionStatusChanged() {
    if (mounted) {
      setState(() {
        _subscriptionStatus = _statusNotifier.status;
      });
    }
  }

  @override
  void dispose() {
    _statusNotifier.removeListener(_onSubscriptionStatusChanged);
    _statusNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final authState = await _authService.getAuthState();
      final packageInfo = await PackageInfo.fromPlatform();
      final subscriptionStatus =
          await _subscriptionService.getSubscriptionStatus();

      if (mounted) {
        setState(() {
          _authState = authState;
          _packageInfo = packageInfo;
          _subscriptionStatus = subscriptionStatus;
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

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Return to previous screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleViewLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NewLogsViewerScreen(),
      ),
    );
  }

  void _handleViewSubscription() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionStatusScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSigningOut
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Signing out...'),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    _buildAccountSection(),
                    const Divider(),
                    _buildSubscriptionSection(),
                    const Divider(),
                    _buildAppSection(),
                  ],
                ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Account',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        if (_authState?.isAuthenticated == true) ...[
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Email'),
            subtitle: Text(_authState?.userEmail ?? 'Not available'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: _handleSignOut,
            trailing: const Icon(Icons.chevron_right),
          ),
        ] else ...[
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Not signed in'),
            subtitle: Text('Sign in to sync your documents'),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionSection() {
    final isCloudSyncEnabled = _statusNotifier.isCloudSyncEnabled;
    final statusText = _getSubscriptionStatusText();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Subscription',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ListTile(
          leading: Icon(
            _getSubscriptionStatusIcon(),
            color: _getSubscriptionStatusColor(),
          ),
          title: const Text('Status'),
          subtitle: Text(statusText),
          trailing: const Icon(Icons.chevron_right),
          onTap: _handleViewSubscription,
        ),
        ListTile(
          leading: Icon(
            isCloudSyncEnabled ? Icons.cloud_done : Icons.cloud_off,
            color: isCloudSyncEnabled ? Colors.green : Colors.grey,
          ),
          title: const Text('Cloud Sync'),
          subtitle: Text(
            isCloudSyncEnabled ? 'Enabled' : 'Disabled',
            style: TextStyle(
              color: isCloudSyncEnabled ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _handleViewSubscription,
              icon: const Icon(Icons.card_membership),
              label: const Text('View Subscription'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'App',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('View Logs'),
          subtitle: const Text('View app logs for debugging'),
          onTap: _handleViewLogs,
          trailing: const Icon(Icons.chevron_right),
        ),
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('App Version'),
          subtitle: Text(
            _packageInfo != null
                ? 'Version ${_packageInfo!.version} (${_packageInfo!.buildNumber})'
                : 'Loading...',
          ),
        ),
      ],
    );
  }

  String _getSubscriptionStatusText() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.active:
        return 'Active';
      case SubscriptionStatus.gracePeriod:
        return 'Grace Period';
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.none:
        return 'None';
    }
  }

  IconData _getSubscriptionStatusIcon() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.active:
        return Icons.check_circle;
      case SubscriptionStatus.gracePeriod:
        return Icons.warning;
      case SubscriptionStatus.expired:
        return Icons.error_outline;
      case SubscriptionStatus.none:
        return Icons.info_outline;
    }
  }

  Color _getSubscriptionStatusColor() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.active:
        return Colors.green;
      case SubscriptionStatus.gracePeriod:
        return Colors.orange;
      case SubscriptionStatus.expired:
        return Colors.red;
      case SubscriptionStatus.none:
        return Colors.grey;
    }
  }
}
