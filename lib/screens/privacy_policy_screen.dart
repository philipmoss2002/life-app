import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Your Privacy Matters',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last Updated: December 1, 2025',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            icon: Icons.shield_outlined,
            title: 'What We Collect',
            content: 'Nothing. We don\'t collect any personal information.',
            color: Colors.green,
          ),
          _buildSection(
            icon: Icons.phone_android,
            title: 'Where Your Data Lives',
            content:
                'On your device only. All documents, files, and information are stored locally on your device using SQLite database.',
            color: Colors.blue,
          ),
          _buildSection(
            icon: Icons.cloud_off,
            title: 'What We Share',
            content:
                'Nothing. Your data never leaves your device. No cloud storage, no servers, no third parties.',
            color: Colors.orange,
          ),
          _buildSection(
            icon: Icons.security,
            title: 'Your Control',
            content:
                'You can view, edit, or delete any document anytime. Uninstall the app to remove all data. Your original files are never modified or deleted.',
            color: Colors.purple,
          ),
          _buildSection(
            icon: Icons.verified_user,
            title: 'Permissions We Need',
            content:
                '• File Access: To let you attach files to documents (only files you select)\n• Notifications: To remind you about upcoming renewal dates (optional)',
            color: Colors.teal,
          ),
          _buildSection(
            icon: Icons.block,
            title: 'No Tracking',
            content:
                '• No analytics\n• No advertisements\n• No user accounts\n• No internet connection required',
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bottom Line',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your household documents are private. They stay on your device, under your control, always.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Data Storage Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            'Local Storage Only',
            'All data is stored exclusively on your device using SQLite database. No data is transmitted over the internet.',
          ),
          _buildInfoCard(
            'File Access',
            'The app only accesses files you explicitly select through the file picker. File paths are stored to allow you to reopen files later.',
          ),
          _buildInfoCard(
            'Data Security',
            'Your data is protected by your device\'s security measures (PIN, password, biometric authentication). We recommend keeping your device locked and secure.',
          ),
          _buildInfoCard(
            'Complete Data Removal',
            'To completely remove all app data, simply uninstall the app from your device. This will delete the app\'s database and all document information. Your original files will remain on your device.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Third-Party Libraries',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The app uses the following open-source libraries for functionality:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildLibraryItem('Flutter Framework', 'For app development'),
          _buildLibraryItem('SQLite (sqflite)', 'For local database storage'),
          _buildLibraryItem('file_picker', 'For selecting files'),
          _buildLibraryItem('open_file', 'For opening files'),
          _buildLibraryItem(
              'flutter_local_notifications', 'For local notifications'),
          const SizedBox(height: 8),
          const Text(
            'These libraries operate locally on your device and do not transmit data externally.',
            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLibraryItem(String name, String purpose) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ': $purpose'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
