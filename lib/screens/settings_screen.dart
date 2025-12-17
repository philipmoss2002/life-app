import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/subscription_service.dart';
import 'sign_in_screen.dart';
import 'privacy_policy_screen.dart';
import 'subscription_plans_screen.dart';
import 'subscription_status_screen.dart';
import 'storage_usage_screen.dart';
import 'devices_list_screen.dart';
import 'sync_settings_screen.dart';
import 'account_deletion_screen.dart';
import 'subscription_debug_screen.dart';
import 'sync_diagnostic_screen.dart';
import 'detailed_sync_debug_screen.dart';
import 's3_test_screen.dart';
import 'path_debug_screen.dart';
import 'upload_download_test_screen.dart';
import 'error_trace_screen.dart';
import 'minimal_sync_test_screen.dart';
import 'api_test_screen.dart';
import 'log_viewer_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  SubscriptionStatus _subscriptionStatus = SubscriptionStatus.none;
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    // Check auth status when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.checkAuthStatus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to auth changes and refresh subscription status
    final authProvider = Provider.of<AuthProvider>(context);
    if (authProvider.isAuthenticated) {
      // User signed in, refresh subscription status
      _loadSubscriptionStatus();
    } else {
      // User signed out, reset subscription status
      if (mounted) {
        setState(() {
          _subscriptionStatus = SubscriptionStatus.none;
          _isLoadingSubscription = false;
        });
      }
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      // Ensure subscription service is initialized
      try {
        await _subscriptionService.initialize();
        debugPrint('Subscription service initialized in settings');
      } catch (e) {
        debugPrint('Subscription service already initialized or failed: $e');
      }

      final status = await _subscriptionService.getSubscriptionStatus();
      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading subscription status: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return ListView(
            children: [
              _buildAccountSection(context, authProvider),
              const Divider(),
              _buildSubscriptionSection(context, authProvider),
              const Divider(),
              _buildAppSection(context),
              const Divider(),
              _buildAboutSection(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, AuthProvider authProvider) {
    final isAuthenticated = authProvider.isAuthenticated;
    final user = authProvider.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Account',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        if (isAuthenticated && user != null) ...[
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(user.email),
            subtitle: const Text('Signed in'),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Cloud Sync'),
            subtitle: const Text('Enabled'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Active',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () => _handleSignOut(context, authProvider),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red.shade600),
            title: Text(
              'Delete Account',
              style: TextStyle(color: Colors.red.shade600),
            ),
            subtitle:
                const Text('Permanently delete your account and all data'),
            onTap: () => _handleDeleteAccount(context),
          ),
        ] else ...[
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('Sign In'),
            subtitle: const Text('Access cloud sync features'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _handleSignIn(context),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_off),
            title: const Text('Cloud Sync'),
            subtitle: const Text('Sign in to enable'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Disabled',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubscriptionSection(
      BuildContext context, AuthProvider authProvider) {
    final isAuthenticated = authProvider.isAuthenticated;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Subscription',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        if (!isAuthenticated) ...[
          ListTile(
            leading: const Icon(Icons.workspace_premium),
            title: const Text('Premium Plans'),
            subtitle: const Text('Unlock cloud sync and more'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _navigateToPlans(context),
          ),
        ] else ...[
          if (_isLoadingSubscription)
            const ListTile(
              leading: Icon(Icons.hourglass_empty),
              title: Text('Loading subscription status...'),
            )
          else ...[
            ListTile(
              leading: Icon(
                _subscriptionStatus == SubscriptionStatus.active
                    ? Icons.check_circle
                    : Icons.workspace_premium,
                color: _subscriptionStatus == SubscriptionStatus.active
                    ? Colors.green
                    : null,
              ),
              title: Text(
                _subscriptionStatus == SubscriptionStatus.active
                    ? 'Premium Active'
                    : 'Upgrade to Premium',
              ),
              subtitle: Text(_getSubscriptionSubtitle()),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_subscriptionStatus != SubscriptionStatus.active)
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _refreshSubscriptionStatus,
                      tooltip: 'Check for purchases',
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _navigateToSubscriptionStatus(context),
            ),
          ],
        ],
      ],
    );
  }

  String _getSubscriptionSubtitle() {
    switch (_subscriptionStatus) {
      case SubscriptionStatus.active:
        return 'Manage your subscription';
      case SubscriptionStatus.gracePeriod:
        return 'Grace period - Update payment';
      case SubscriptionStatus.expired:
        return 'Subscription expired';
      case SubscriptionStatus.none:
        return 'Unlock cloud sync features';
    }
  }

  Future<void> _navigateToPlans(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SubscriptionPlansScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadSubscriptionStatus();
    }
  }

  Future<void> _navigateToSubscriptionStatus(BuildContext context) async {
    if (_subscriptionStatus == SubscriptionStatus.none) {
      await _navigateToPlans(context);
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SubscriptionStatusScreen(),
        ),
      );
      if (mounted) {
        await _loadSubscriptionStatus();
      }
    }
  }

  Widget _buildAppSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'App',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.sync_outlined),
          title: const Text('Sync Settings'),
          subtitle: const Text('Control when and how sync occurs'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SyncSettingsScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          subtitle: const Text('Manage notification preferences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to notifications settings
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.storage_outlined),
          title: const Text('Storage'),
          subtitle: const Text('Manage local and cloud storage'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StorageUsageScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.devices),
          title: const Text('Connected Devices'),
          subtitle: const Text('Manage devices with access to your account'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DevicesListScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outlined),
          title: const Text('Version'),
          subtitle: const Text('1.0.8'),
        ),
        ListTile(
          leading: const Icon(Icons.bug_report),
          title: const Text('Subscription Debug'),
          subtitle: const Text('Debug subscription issues'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubscriptionDebugScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.sync_problem),
          title: const Text('Sync Diagnostics'),
          subtitle: const Text('Diagnose sync issues'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SyncDiagnosticScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.api),
          title: const Text('API Test'),
          subtitle: const Text('Test Amplify API connectivity'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ApiTestScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.terminal),
          title: const Text('App Logs'),
          subtitle: const Text('View real-time app logs'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LogViewerScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.bug_report_outlined),
          title: const Text('Detailed Sync Debug'),
          subtitle: const Text('Step-by-step sync testing'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DetailedSyncDebugScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload),
          title: const Text('S3 Direct Test'),
          subtitle: const Text('Test S3 upload permissions'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const S3TestScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: const Text('S3 Path Debug'),
          subtitle: const Text('View S3 path structure'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PathDebugScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.sync_alt),
          title: const Text('Upload/Download Test'),
          subtitle: const Text('Test exact upload/download paths'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const UploadDownloadTestScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.search),
          title: const Text('Error Trace'),
          subtitle: const Text('Trace NoSuchKey error source'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ErrorTraceScreen(),
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.science),
          title: const Text('Minimal Sync Test'),
          subtitle: const Text('Test upload without services'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MinimalSyncTestScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleSignIn(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );

    if (result == true && context.mounted) {
      // Refresh auth status
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.checkAuthStatus();

      // Reload subscription status for authenticated user
      await _loadSubscriptionStatus();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _handleSignOut(
      BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out? Your documents will remain on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await authProvider.signOut();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed out successfully'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    // Show initial warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
            const SizedBox(width: 8),
            const Text('Delete Account'),
          ],
        ),
        content: const Text(
          'This will permanently delete your account and all associated data.\n\n'
          'This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Navigate to detailed account deletion screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AccountDeletionScreen(),
        ),
      );
    }
  }

  Future<void> _refreshSubscriptionStatus() async {
    setState(() {
      _isLoadingSubscription = true;
    });

    try {
      debugPrint('Manually refreshing subscription status...');

      // Force check for purchases
      await _subscriptionService.forceCheckPurchases();

      // Wait a moment for the purchase stream to process
      await Future.delayed(const Duration(seconds: 2));

      // Get updated status
      final status = await _subscriptionService.getSubscriptionStatus();

      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
          _isLoadingSubscription = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == SubscriptionStatus.active
                ? 'Premium subscription found!'
                : 'No active subscription found'),
            backgroundColor: status == SubscriptionStatus.active
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing subscription: $e');
      if (mounted) {
        setState(() {
          _isLoadingSubscription = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking subscription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
