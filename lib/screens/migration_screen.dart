import 'package:flutter/material.dart';
import '../services/migration_service.dart';

/// Screen for managing document migration from local to cloud storage
/// Shows migration prompt, progress, and completion status
class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final MigrationService _migrationService = MigrationService();
  MigrationProgress? _progress;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProgress();
    _listenToProgress();
  }

  void _loadCurrentProgress() {
    setState(() {
      _progress = _migrationService.currentProgress;
    });
  }

  void _listenToProgress() {
    _migrationService.progressStream.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _startMigration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _migrationService.startMigration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancelMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Migration'),
        content: const Text(
          'Are you sure you want to cancel the migration? '
          'You can resume it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _migrationService.cancelMigration();
    }
  }

  Future<void> _retryFailedDocuments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _migrationService.retryFailedDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Migration'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_progress == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_progress!.status) {
      case MigrationStatus.notStarted:
        return _buildMigrationPrompt();
      case MigrationStatus.inProgress:
        return _buildMigrationProgress();
      case MigrationStatus.completed:
        return _buildMigrationComplete();
      case MigrationStatus.failed:
        return _buildMigrationFailed();
      case MigrationStatus.cancelled:
        return _buildMigrationCancelled();
    }
  }

  Widget _buildMigrationPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.cloud_upload,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Migrate to Cloud',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your documents are currently stored only on this device. '
            'Migrate them to the cloud to access them from any device.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _startMigration,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Start Migration',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationProgress() {
    final progress = _progress!;
    final percentage = (progress.progressPercentage * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.cloud_sync,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),
          const Text(
            'Migrating Documents',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          LinearProgressIndicator(
            value: progress.progressPercentage,
            minHeight: 8,
          ),
          const SizedBox(height: 16),
          Text(
            '$percentage% Complete',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${progress.migratedDocuments} of ${progress.totalDocuments} documents migrated',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          if (progress.failedDocuments > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${progress.failedDocuments} failed',
              style: const TextStyle(fontSize: 14, color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: _cancelMigration,
            child: const Text('Cancel Migration'),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationComplete() {
    final progress = _progress!;
    final hasFailures = progress.failures.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            hasFailures ? Icons.warning : Icons.check_circle,
            size: 80,
            color: hasFailures ? Colors.orange : Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            hasFailures
                ? 'Migration Completed with Errors'
                : 'Migration Complete!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            hasFailures
                ? '${progress.migratedDocuments} documents migrated successfully, '
                    '${progress.failedDocuments} failed.'
                : 'All ${progress.migratedDocuments} documents have been migrated to the cloud.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (hasFailures) ...[
            const SizedBox(height: 32),
            const Text(
              'Failed Documents:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: progress.failures.length,
                itemBuilder: (context, index) {
                  final failure = progress.failures[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: Text(failure.documentTitle),
                      subtitle: Text(
                        failure.error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        'Retries: ${failure.retryCount}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _retryFailedDocuments,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Retry Failed Documents'),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationFailed() {
    final progress = _progress!;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.error,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 24),
          const Text(
            'Migration Failed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            progress.error ?? 'An unknown error occurred during migration.',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _startMigration,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Try Again'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildMigrationCancelled() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.cancel,
            size: 80,
            color: Colors.orange,
          ),
          const SizedBox(height: 24),
          const Text(
            'Migration Cancelled',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'The migration was cancelled. You can resume it anytime.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _startMigration,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Resume Migration'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
