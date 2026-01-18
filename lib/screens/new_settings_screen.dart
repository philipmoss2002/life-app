import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/authentication_service.dart';
import '../models/auth_state.dart';
import 'new_logs_viewer_screen.dart';

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

  AuthState? _authState;
  PackageInfo? _packageInfo;
  bool _isLoading = true;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authState = await _authService.getAuthState();
      final packageInfo = await PackageInfo.fromPlatform();

      if (mounted) {
        setState(() {
          _authState = authState;
          _packageInfo = packageInfo;
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
}
