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
            'Last Updated: December 8, 2025',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            icon: Icons.shield_outlined,
            title: 'What We Collect',
            content:
                'Free users: Nothing. Premium users: Email for authentication, document metadata, and files (encrypted in AWS).',
            color: Colors.green,
          ),
          _buildSection(
            icon: Icons.phone_android,
            title: 'Where Your Data Lives',
            content:
                'Free users: On your device only. Premium users: Encrypted in AWS (DynamoDB for metadata, S3 for files) with local caching.',
            color: Colors.blue,
          ),
          _buildSection(
            icon: Icons.cloud_off,
            title: 'What We Share',
            content:
                'We do NOT share your document content with third parties. Premium users: AWS provides infrastructure only.',
            color: Colors.orange,
          ),
          _buildSection(
            icon: Icons.security,
            title: 'Your Control',
            content:
                'You can view, edit, or delete any document anytime. Premium users: Request account deletion to remove all cloud data within 30 days.',
            color: Colors.purple,
          ),
          _buildSection(
            icon: Icons.lock,
            title: 'Encryption & Security',
            content:
                'Premium users: TLS 1.3 encryption in transit, AES-256 encryption at rest. AWS provides industry-standard security with continuous monitoring.',
            color: Colors.indigo,
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
            title: 'No Content Analysis',
            content:
                '• We do NOT access or analyze your document content\n• No advertisements\n• No tracking for marketing\n• Free users: No internet required',
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
                  'Free users: Your documents stay on your device, under your control. Premium users: Your documents are encrypted and securely stored in AWS. We never access or analyze your content.',
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
            'Free Users - Local Storage',
            'All data is stored exclusively on your device using SQLite database. No data is transmitted over the internet.',
          ),
          _buildInfoCard(
            'Premium Users - AWS Cloud Storage',
            'Document metadata stored in AWS DynamoDB, files in AWS S3. All data encrypted with AES-256 at rest and TLS 1.3 in transit. Stored in your selected AWS region.',
          ),
          _buildInfoCard(
            'File Access',
            'The app only accesses files you explicitly select through the file picker. File paths are stored to allow you to reopen files later.',
          ),
          _buildInfoCard(
            'Data Security',
            'Local data protected by device security. Premium users: AWS provides industry-standard security with continuous monitoring, IAM access controls, and encryption.',
          ),
          _buildInfoCard(
            'Data Retention',
            'Free users: Data retained until you delete it. Premium users: Data retained while subscription active, plus 30-day grace period after cancellation. Account deletion removes all data within 30 days.',
          ),
          _buildInfoCard(
            'Complete Data Removal',
            'Free users: Uninstall the app. Premium users: Request account deletion through the app - all cloud data permanently deleted within 30 days.',
          ),
          const SizedBox(height: 24),
          const Text(
            'Third-Party Services',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(
            'Amazon Web Services (Premium Only)',
            'AWS Cognito (authentication), DynamoDB (metadata), S3 (files). AWS complies with SOC 2, ISO 27001, GDPR. AWS does not access your document content.',
          ),
          _buildInfoCard(
            'Payment Processing (Premium Only)',
            'In-app purchases processed by Google Play or Apple App Store. We verify subscription status but do not receive payment details.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Third-Party Libraries',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'The app uses the following open-source libraries:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildLibraryItem('Flutter Framework', 'For app development'),
          _buildLibraryItem('SQLite (sqflite)', 'For local database storage'),
          _buildLibraryItem('file_picker', 'For selecting files'),
          _buildLibraryItem('open_file', 'For opening files'),
          _buildLibraryItem(
              'flutter_local_notifications', 'For local notifications'),
          _buildLibraryItem('AWS Amplify', 'For cloud sync (premium only)'),
          const SizedBox(height: 8),
          const Text(
            'These libraries operate locally or connect only to AWS (premium users).',
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
