import 'package:flutter/material.dart';
import '../screens/migration_screen.dart';
import '../services/migration_service.dart';

/// Widget that prompts users to migrate their documents to cloud storage
/// Shown after a user upgrades to premium subscription
class MigrationPrompt extends StatelessWidget {
  const MigrationPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_upload,
                  color: Colors.blue,
                  size: 32,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Migrate to Cloud',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    // Dismiss the prompt
                    // In a real app, you might want to save a preference
                    // to not show this again
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'You now have access to cloud sync! Migrate your existing '
              'documents to access them from any device.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // Dismiss for now
                  },
                  child: const Text('Later'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MigrationScreen(),
                      ),
                    );
                  },
                  child: const Text('Start Migration'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to check if migration prompt should be shown
Future<bool> shouldShowMigrationPrompt() async {
  final migrationService = MigrationService();
  final progress = migrationService.currentProgress;

  // Show prompt if migration hasn't been completed
  return progress.status == MigrationStatus.notStarted ||
      progress.status == MigrationStatus.cancelled;
}
