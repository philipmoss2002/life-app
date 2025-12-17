import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Service to capture and store logs for viewing in the app
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final Queue<LogEntry> _logs = Queue<LogEntry>();
  static const int maxLogs = 1000; // Keep last 1000 log entries

  /// Add a log entry
  void log(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );

    _logs.add(entry);

    // Keep only the last maxLogs entries
    while (_logs.length > maxLogs) {
      _logs.removeFirst();
    }

    // Also print to debug console if available
    debugPrint('[${level.name.toUpperCase()}] $message');
  }

  /// Get all log entries
  List<LogEntry> getAllLogs() {
    return _logs.toList();
  }

  /// Get logs filtered by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
  }

  /// Get logs as formatted string
  String getLogsAsString() {
    return _logs.map((log) => log.toString()).join('\n');
  }
}

/// Log entry model
class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  @override
  String toString() {
    final timeStr = timestamp.toLocal().toString().substring(11, 19);
    return '[$timeStr] [${level.name.toUpperCase()}] $message';
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Extension to add logging to any class
extension Logging on Object {
  void logDebug(String message) =>
      LogService().log(message, level: LogLevel.debug);
  void logInfo(String message) =>
      LogService().log(message, level: LogLevel.info);
  void logWarning(String message) =>
      LogService().log(message, level: LogLevel.warning);
  void logError(String message) =>
      LogService().log(message, level: LogLevel.error);
}
