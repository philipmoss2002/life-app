import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  LogLevel? _selectedLevel;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Logs'),
        actions: [
          PopupMenuButton<LogLevel?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (level) {
              setState(() {
                _selectedLevel = level;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Logs'),
              ),
              const PopupMenuItem(
                value: LogLevel.error,
                child: Text('Errors Only'),
              ),
              const PopupMenuItem(
                value: LogLevel.warning,
                child: Text('Warnings Only'),
              ),
              const PopupMenuItem(
                value: LogLevel.info,
                child: Text('Info Only'),
              ),
              const PopupMenuItem(
                value: LogLevel.debug,
                child: Text('Debug Only'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyLogsToClipboard,
            tooltip: 'Copy logs to clipboard',
          ),
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedLevel != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Showing ${_selectedLevel!.name} logs only',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedLevel = null),
                    child: const Text('Show All'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildLogsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _scrollToBottom,
        tooltip: 'Scroll to bottom',
        child: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }

  Widget _buildLogsList() {
    final logs = _selectedLevel == null
        ? LogService().getAllLogs()
        : LogService().getLogsByLevel(_selectedLevel!);

    if (logs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No logs available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Logs will appear here when the app performs actions',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogEntry(log);
      },
    );
  }

  Widget _buildLogEntry(LogEntry log) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (log.level) {
      case LogLevel.error:
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[800]!;
        icon = Icons.error_outline;
        break;
      case LogLevel.warning:
        backgroundColor = Colors.orange[50]!;
        textColor = Colors.orange[800]!;
        icon = Icons.warning_outlined;
        break;
      case LogLevel.info:
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[800]!;
        icon = Icons.info_outline;
        break;
      case LogLevel.debug:
        backgroundColor = Colors.grey[50]!;
        textColor = Colors.grey[800]!;
        icon = Icons.bug_report_outlined;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  log.timestamp.toLocal().toString().substring(11, 19),
                  style: TextStyle(
                    fontSize: 10,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              LogService().clearLogs();
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _copyLogsToClipboard() {
    final logsText = LogService().getLogsAsString();
    Clipboard.setData(ClipboardData(text: logsText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
