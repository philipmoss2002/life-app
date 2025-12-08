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

  Future<void> _loadSubscriptionStatus() async {
    try {
      final status = await _subscriptionService.getSubscriptionStatus();
      if (mounted) {
        setState(() {
          _subscriptionStatus = status;
          _isLoadingSubscription = false;
        });
      }
    } catch (e) {
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
              trailing: const Icon(Icons.chevron_right),
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
          subtitle: const Text('1.0.0'),
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
}
