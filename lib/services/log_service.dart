import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Service to capture and store logs for viewing in the app
/// Enhanced with structured logging, performance metrics, and audit trails
class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final Queue<LogEntry> _logs = Queue<LogEntry>();
  final Queue<FileOperationLog> _fileOperationLogs = Queue<FileOperationLog>();
  final Queue<AuditLogEntry> _auditLogs = Queue<AuditLogEntry>();
  final Queue<PerformanceMetric> _performanceMetrics =
      Queue<PerformanceMetric>();

  static const int maxLogs = 1000; // Keep last 1000 log entries
  static const int maxFileOperationLogs = 500;
  static const int maxAuditLogs = 500;
  static const int maxPerformanceMetrics = 500;

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

  /// Log a file operation with structured data (Requirement 7.1)
  void logFileOperation({
    required String operation,
    required String outcome,
    String? userIdentifier,
    String? syncId,
    String? fileName,
    String? s3Key,
    int? fileSizeBytes,
    String? errorCode,
    String? errorMessage,
    int? retryAttempt,
    Map<String, dynamic>? additionalData,
  }) {
    final entry = FileOperationLog(
      operation: operation,
      outcome: outcome,
      timestamp: DateTime.now(),
      userIdentifier: userIdentifier,
      syncId: syncId,
      fileName: fileName,
      s3Key: s3Key,
      fileSizeBytes: fileSizeBytes,
      errorCode: errorCode,
      errorMessage: errorMessage,
      retryAttempt: retryAttempt,
      additionalData: additionalData,
    );

    _fileOperationLogs.add(entry);

    // Keep only the last maxFileOperationLogs entries
    while (_fileOperationLogs.length > maxFileOperationLogs) {
      _fileOperationLogs.removeFirst();
    }

    // Also log to standard log
    final level = outcome == 'success' ? LogLevel.info : LogLevel.error;
    log(entry.toFormattedString(), level: level);
  }

  /// Log an audit event for security-sensitive operations (Requirement 7.1, 7.4)
  void logAuditEvent({
    required String eventType,
    required String action,
    String? userIdentifier,
    String? resourceId,
    String? outcome,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    final entry = AuditLogEntry(
      eventType: eventType,
      action: action,
      timestamp: DateTime.now(),
      userIdentifier: userIdentifier,
      resourceId: resourceId,
      outcome: outcome,
      details: details,
      metadata: metadata,
    );

    _auditLogs.add(entry);

    // Keep only the last maxAuditLogs entries
    while (_auditLogs.length > maxAuditLogs) {
      _auditLogs.removeFirst();
    }

    // Also log to standard log
    log(entry.toFormattedString(), level: LogLevel.info);
  }

  /// Record a performance metric (Requirement 7.3)
  void recordPerformanceMetric({
    required String operation,
    required Duration duration,
    String? userIdentifier,
    String? resourceId,
    int? dataSizeBytes,
    bool? success,
    Map<String, dynamic>? additionalMetrics,
  }) {
    final metric = PerformanceMetric(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
      userIdentifier: userIdentifier,
      resourceId: resourceId,
      dataSizeBytes: dataSizeBytes,
      success: success,
      additionalMetrics: additionalMetrics,
    );

    _performanceMetrics.add(metric);

    // Keep only the last maxPerformanceMetrics entries
    while (_performanceMetrics.length > maxPerformanceMetrics) {
      _performanceMetrics.removeFirst();
    }

    // Log slow operations (> 5 seconds)
    if (duration.inSeconds > 5) {
      log(
        '⚠️ Slow operation detected: $operation took ${duration.inSeconds}s',
        level: LogLevel.warning,
      );
    }
  }

  /// Get all log entries
  List<LogEntry> getAllLogs() {
    return _logs.toList();
  }

  /// Get logs filtered by level
  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// Get all file operation logs
  List<FileOperationLog> getFileOperationLogs() {
    return _fileOperationLogs.toList();
  }

  /// Get file operation logs filtered by outcome
  List<FileOperationLog> getFileOperationLogsByOutcome(String outcome) {
    return _fileOperationLogs.where((log) => log.outcome == outcome).toList();
  }

  /// Get file operation logs for a specific user
  List<FileOperationLog> getFileOperationLogsByUser(String userIdentifier) {
    return _fileOperationLogs
        .where((log) => log.userIdentifier == userIdentifier)
        .toList();
  }

  /// Get all audit logs
  List<AuditLogEntry> getAuditLogs() {
    return _auditLogs.toList();
  }

  /// Get audit logs filtered by event type
  List<AuditLogEntry> getAuditLogsByEventType(String eventType) {
    return _auditLogs.where((log) => log.eventType == eventType).toList();
  }

  /// Get audit logs for a specific user
  List<AuditLogEntry> getAuditLogsByUser(String userIdentifier) {
    return _auditLogs
        .where((log) => log.userIdentifier == userIdentifier)
        .toList();
  }

  /// Get all performance metrics
  List<PerformanceMetric> getPerformanceMetrics() {
    return _performanceMetrics.toList();
  }

  /// Get performance metrics for a specific operation
  List<PerformanceMetric> getPerformanceMetricsByOperation(String operation) {
    return _performanceMetrics
        .where((metric) => metric.operation == operation)
        .toList();
  }

  /// Get average duration for an operation
  Duration? getAverageOperationDuration(String operation) {
    final metrics = getPerformanceMetricsByOperation(operation);
    if (metrics.isEmpty) return null;

    final totalMicroseconds =
        metrics.fold<int>(0, (sum, m) => sum + m.duration.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ metrics.length);
  }

  /// Get success rate for file operations
  double getFileOperationSuccessRate() {
    if (_fileOperationLogs.isEmpty) return 0.0;

    final successCount =
        _fileOperationLogs.where((log) => log.outcome == 'success').length;
    return successCount / _fileOperationLogs.length;
  }

  /// Get recent logs (last N minutes)
  List<LogEntry> getRecentLogs(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _logs.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }

  /// Get recent file operation logs (last N minutes)
  List<FileOperationLog> getRecentFileOperationLogs(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _fileOperationLogs
        .where((log) => log.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Get recent audit logs (last N minutes)
  List<AuditLogEntry> getRecentAuditLogs(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _auditLogs.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }

  /// Get recent performance metrics (last N minutes)
  List<PerformanceMetric> getRecentPerformanceMetrics(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _performanceMetrics
        .where((metric) => metric.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
  }

  /// Clear file operation logs
  void clearFileOperationLogs() {
    _fileOperationLogs.clear();
  }

  /// Clear audit logs
  void clearAuditLogs() {
    _auditLogs.clear();
  }

  /// Clear performance metrics
  void clearPerformanceMetrics() {
    _performanceMetrics.clear();
  }

  /// Clear all logs and metrics
  void clearAll() {
    clearLogs();
    clearFileOperationLogs();
    clearAuditLogs();
    clearPerformanceMetrics();
  }

  /// Get logs as formatted string
  String getLogsAsString() {
    return _logs.map((log) => log.toString()).join('\n');
  }

  /// Get file operation logs as formatted string
  String getFileOperationLogsAsString() {
    return _fileOperationLogs.map((log) => log.toFormattedString()).join('\n');
  }

  /// Get audit logs as formatted string
  String getAuditLogsAsString() {
    return _auditLogs.map((log) => log.toFormattedString()).join('\n');
  }

  /// Get performance metrics as formatted string
  String getPerformanceMetricsAsString() {
    return _performanceMetrics
        .map((metric) => metric.toFormattedString())
        .join('\n');
  }

  /// Get comprehensive statistics
  LogStatistics getStatistics() {
    return LogStatistics(
      totalLogs: _logs.length,
      totalFileOperationLogs: _fileOperationLogs.length,
      totalAuditLogs: _auditLogs.length,
      totalPerformanceMetrics: _performanceMetrics.length,
      fileOperationSuccessRate: getFileOperationSuccessRate(),
      errorCount: _logs.where((log) => log.level == LogLevel.error).length,
      warningCount: _logs.where((log) => log.level == LogLevel.warning).length,
    );
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

/// Structured file operation log (Requirement 7.1, 7.2)
class FileOperationLog {
  final String operation;
  final String outcome;
  final DateTime timestamp;
  final String? userIdentifier;
  final String? syncId;
  final String? fileName;
  final String? s3Key;
  final int? fileSizeBytes;
  final String? errorCode;
  final String? errorMessage;
  final int? retryAttempt;
  final Map<String, dynamic>? additionalData;

  FileOperationLog({
    required this.operation,
    required this.outcome,
    required this.timestamp,
    this.userIdentifier,
    this.syncId,
    this.fileName,
    this.s3Key,
    this.fileSizeBytes,
    this.errorCode,
    this.errorMessage,
    this.retryAttempt,
    this.additionalData,
  });

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write('FileOperation: $operation | ');
    buffer.write('Outcome: $outcome | ');
    buffer.write('Time: ${timestamp.toIso8601String()} | ');

    if (userIdentifier != null) {
      // Mask user identifier for privacy (show first 8 chars)
      final masked = userIdentifier!.length > 8
          ? '${userIdentifier!.substring(0, 8)}...'
          : userIdentifier;
      buffer.write('User: $masked | ');
    }

    if (syncId != null) buffer.write('SyncId: $syncId | ');
    if (fileName != null) buffer.write('File: $fileName | ');
    if (fileSizeBytes != null) {
      buffer.write('Size: ${_formatBytes(fileSizeBytes!)} | ');
    }
    if (errorCode != null) buffer.write('ErrorCode: $errorCode | ');
    if (errorMessage != null) buffer.write('Error: $errorMessage | ');
    if (retryAttempt != null) buffer.write('Retry: $retryAttempt | ');

    return buffer.toString().trimRight();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() => toFormattedString();
}

/// Audit log entry for security-sensitive operations (Requirement 7.1, 7.4)
class AuditLogEntry {
  final String eventType;
  final String action;
  final DateTime timestamp;
  final String? userIdentifier;
  final String? resourceId;
  final String? outcome;
  final String? details;
  final Map<String, dynamic>? metadata;

  AuditLogEntry({
    required this.eventType,
    required this.action,
    required this.timestamp,
    this.userIdentifier,
    this.resourceId,
    this.outcome,
    this.details,
    this.metadata,
  });

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write('AUDIT: $eventType | ');
    buffer.write('Action: $action | ');
    buffer.write('Time: ${timestamp.toIso8601String()} | ');

    if (userIdentifier != null) {
      // Mask user identifier for privacy
      final masked = userIdentifier!.length > 8
          ? '${userIdentifier!.substring(0, 8)}...'
          : userIdentifier;
      buffer.write('User: $masked | ');
    }

    if (resourceId != null) buffer.write('Resource: $resourceId | ');
    if (outcome != null) buffer.write('Outcome: $outcome | ');
    if (details != null) buffer.write('Details: $details | ');

    return buffer.toString().trimRight();
  }

  @override
  String toString() => toFormattedString();
}

/// Performance metric for tracking operation duration (Requirement 7.3)
class PerformanceMetric {
  final String operation;
  final Duration duration;
  final DateTime timestamp;
  final String? userIdentifier;
  final String? resourceId;
  final int? dataSizeBytes;
  final bool? success;
  final Map<String, dynamic>? additionalMetrics;

  PerformanceMetric({
    required this.operation,
    required this.duration,
    required this.timestamp,
    this.userIdentifier,
    this.resourceId,
    this.dataSizeBytes,
    this.success,
    this.additionalMetrics,
  });

  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write('Performance: $operation | ');
    buffer.write('Duration: ${duration.inMilliseconds}ms | ');
    buffer.write('Time: ${timestamp.toIso8601String()} | ');

    if (success != null) {
      buffer.write('Success: ${success! ? "✓" : "✗"} | ');
    }

    if (dataSizeBytes != null) {
      final throughput = dataSizeBytes! / duration.inSeconds;
      buffer.write('Throughput: ${_formatBytes(throughput.round())}/s | ');
    }

    return buffer.toString().trimRight();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  String toString() => toFormattedString();
}

/// Log statistics summary
class LogStatistics {
  final int totalLogs;
  final int totalFileOperationLogs;
  final int totalAuditLogs;
  final int totalPerformanceMetrics;
  final double fileOperationSuccessRate;
  final int errorCount;
  final int warningCount;

  LogStatistics({
    required this.totalLogs,
    required this.totalFileOperationLogs,
    required this.totalAuditLogs,
    required this.totalPerformanceMetrics,
    required this.fileOperationSuccessRate,
    required this.errorCount,
    required this.warningCount,
  });

  @override
  String toString() {
    return 'LogStatistics(\n'
        '  Total Logs: $totalLogs\n'
        '  File Operations: $totalFileOperationLogs\n'
        '  Audit Logs: $totalAuditLogs\n'
        '  Performance Metrics: $totalPerformanceMetrics\n'
        '  Success Rate: ${(fileOperationSuccessRate * 100).toStringAsFixed(1)}%\n'
        '  Errors: $errorCount\n'
        '  Warnings: $warningCount\n'
        ')';
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
