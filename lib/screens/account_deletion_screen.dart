import 'package:flutter/material.dart';
import '../services/account_deletion_service.dart';
import '../services/authentication_service.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final AccountDeletionService _deletionService = AccountDeletionService();
  final AuthenticationService _authService = AuthenticationService();

  bool _isDeleting = false;
  bool _confirmationChecked = false;
  AccountDeletionProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    _deletionService.deletionProgress.listen((progress) {
      setState(() {
        _currentProgress = progress;
        _isDeleting = progress.status != AccountDeletionStatus.completed &&
            progress.status != AccountDeletionStatus.failed;
      });

      if (progress.status == AccountDeletionStatus.completed) {
        _showCompletionDialog();
      } else if (progress.status == AccountDeletionStatus.failed) {
        _showErrorDialog(progress.error ?? 'Unknown error occurred');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delete Account'),
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red.shade800,
      ),
      body: _isDeleting ? _buildDeletionProgress() : _buildDeletionForm(),
    );
  }

  Widget _buildDeletionForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade600,
                  size: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  'Permanent Account Deletion',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This action cannot be undone',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // What will be deleted section
          _buildSectionHeader('What will be deleted:'),
          const SizedBox(height: 12),
          _buildDeletionItem(
            Icons.description_outlined,
            'All Documents',
            'All your documents and their metadata',
          ),
          _buildDeletionItem(
            Icons.attach_file_outlined,
            'All Files',
            'Photos, PDFs, and other attachments',
          ),
          _buildDeletionItem(
            Icons.cloud_outlined,
            'Cloud Data',
            'All data stored in cloud storage',
          ),
          _buildDeletionItem(
            Icons.sync_outlined,
            'Sync History',
            'All synchronization data and history',
          ),
          _buildDeletionItem(
            Icons.settings_outlined,
            'App Settings',
            'All preferences and configurations',
          ),
          _buildDeletionItem(
            Icons.subscriptions_outlined,
            'Subscription',
            'Premium subscription will be cancelled',
          ),
          _buildDeletionItem(
            Icons.person_outline,
            'User Account',
            'Your account will be permanently deleted',
          ),

          const SizedBox(height: 24),

          // GDPR compliance section
          _buildSectionHeader('Your Rights (GDPR Compliance):'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Right to Erasure (Article 17 GDPR)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• All personal data will be permanently deleted\n'
                  '• Data cannot be recovered after deletion\n'
                  '• Deletion includes all backups and copies\n'
                  '• Process completes within 30 days\n'
                  '• You will receive confirmation when complete',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Alternatives section
          _buildSectionHeader('Consider these alternatives:'),
          const SizedBox(height: 12),
          _buildAlternativeItem(
            Icons.pause_circle_outline,
            'Temporarily Disable Account',
            'Keep your data but stop using the app',
            () => _showTemporaryDisableDialog(),
          ),
          _buildAlternativeItem(
            Icons.download_outlined,
            'Export Your Data',
            'Download a copy of your data first',
            () => _showDataExportDialog(),
          ),
          _buildAlternativeItem(
            Icons.help_outline,
            'Contact Support',
            'Get help with your account issues',
            () => _showContactSupportDialog(),
          ),

          const SizedBox(height: 32),

          // Confirmation checkbox
          CheckboxListTile(
            value: _confirmationChecked,
            onChanged: (value) {
              setState(() {
                _confirmationChecked = value ?? false;
              });
            },
            title: const Text(
              'I understand that this action is permanent and cannot be undone. '
              'All my data will be permanently deleted.',
            ),
            subtitle: const Text(
              'Check this box to confirm you want to delete your account.',
              style: TextStyle(fontSize: 12),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),

          const SizedBox(height: 24),

          // Delete button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmationChecked ? _showFinalConfirmation : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete My Account Permanently',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cancel button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDeletionProgress() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.delete_forever,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              'Deleting Your Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentProgress?.message ?? 'Processing...',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: _currentProgress?.progress ?? 0.0,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
            ),
            const SizedBox(height: 16),
            Text(
              '${((_currentProgress?.progress ?? 0.0) * 100).toInt()}% Complete',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Please do not close the app during this process.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDeletionItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeItem(
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue.shade600),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  void _showFinalConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'Are you absolutely sure you want to delete your account?\n\n'
          'This action is PERMANENT and CANNOT be undone.\n\n'
          'All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Delete My Account'),
          ),
        ],
      ),
    );
  }

  void _startAccountDeletion() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await _deletionService.deleteAccount();
    } catch (e) {
      // Error handling is done through the progress stream
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Account Deleted'),
        content: const Text(
          'Your account and all associated data have been permanently deleted.\n\n'
          'Thank you for using Life App.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Close App'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletion Failed'),
        content: Text(
          'An error occurred while deleting your account:\n\n$error\n\n'
          'Please try again or contact support for assistance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTemporaryDisableDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Temporary Disable'),
        content: const Text(
          'You can temporarily disable your account by signing out and not using the app.\n\n'
          'Your data will remain safe and you can return anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _authService.signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text(
          'Data export functionality is not yet implemented.\n\n'
          'Contact support if you need a copy of your data before deletion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text(
          'If you\'re having issues with the app, our support team can help.\n\n'
          'Email: support@lifeapp.com\n\n'
          'We typically respond within 24 hours.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _deletionService.dispose();
    super.dispose();
  }
}
