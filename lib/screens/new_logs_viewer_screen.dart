import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/log_service.dart';

/// Screen to view and manage application logs
/// Requirements: 9.1, 9.2, 9.3, 9.4, 12.1
class NewLogsViewerScreen extends StatefulWidget {
  const NewLogsViewerScreen({super.key});

  @override
  State<NewLogsViewerScreen> createState() => _NewLogsViewerScreenState();
}

class _NewLogsViewerScreenState extends State<NewLogsViewerScreen> {
  final LogService _logService = LogService();
  LogLevel? _selectedLevel;
  List<LogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      if (_selectedLevel == null) {
        _logs = _logService.getAllLogs();
      } else {
        _logs = _logService.getLogsByLevel(_selectedLevel!);
      }
    });
  }

  Future<void> _copyLogs() async {
    final logsText = _logService.getLogsAsString();
    await Clipboard.setData(ClipboardData(text: logsText));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs copied to clipboard')),
      );
    }
  }

  Future<void> _shareLogs() async {
    final logsText = _logService.getLogsAsString();
    await Share.share(
      logsText,
      subject: 'Household Documents App Logs',
    );
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _logService.clearLogs();
      _loadLogs();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logs cleared')),
        );
      }
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return Icons.bug_report;
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber;
      case LogLevel.error:
        return Icons.error_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogs,
            tooltip: 'Copy Logs',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
            tooltip: 'Share Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearLogs,
            tooltip: 'Clear Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8.0,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedLevel == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = null;
                      _loadLogs();
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Debug'),
                  selected: _selectedLevel == LogLevel.debug,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = selected ? LogLevel.debug : null;
                      _loadLogs();
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Info'),
                  selected: _selectedLevel == LogLevel.info,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = selected ? LogLevel.info : null;
                      _loadLogs();
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Warning'),
                  selected: _selectedLevel == LogLevel.warning,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = selected ? LogLevel.warning : null;
                      _loadLogs();
                    });
                  },
                ),
                FilterChip(
                  label: const Text('Error'),
                  selected: _selectedLevel == LogLevel.error,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLevel = selected ? LogLevel.error : null;
                      _loadLogs();
                    });
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Logs list
          Expanded(
            child: _logs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No logs available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      return ListTile(
                        leading: Icon(
                          _getLevelIcon(log.level),
                          color: _getLevelColor(log.level),
                        ),
                        title: Text(
                          log.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _formatTimestamp(log.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        dense: true,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
