import 'dart:async';
import 'dart:collection';
import 'log_service.dart';

/// Monitoring and alerting service for file operations
/// Tracks success rates, performance metrics, and triggers alerts
/// based on configurable thresholds (Requirement 7.5)
class MonitoringService {
  static final MonitoringService _instance = MonitoringService._internal();
  factory MonitoringService() => _instance;
  MonitoringService._internal();

  final LogService _logService = LogService();
  final Queue<Alert> _alerts = Queue<Alert>();
  final Map<String, OperationMetrics> _operationMetrics = {};

  // Alert thresholds (configurable)
  double successRateThreshold = 0.90; // 90% success rate
  int slowOperationThresholdMs = 5000; // 5 seconds
  int errorRateThresholdPerHour = 10; // 10 errors per hour
  int maxAlerts = 100; // Keep last 100 alerts

  // Monitoring intervals
  Timer? _monitoringTimer;
  Duration monitoringInterval = const Duration(minutes: 5);

  // Alert callbacks
  final List<Function(Alert)> _alertCallbacks = [];

  /// Start monitoring
  void startMonitoring() {
    if (_monitoringTimer != null && _monitoringTimer!.isActive) {
      return; // Already monitoring
    }

    _monitoringTimer = Timer.periodic(monitoringInterval, (_) {
      _checkMetrics();
    });

    _logService.log('📊 Monitoring service started', level: LogLevel.info);
  }

  /// Stop monitoring
  void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _logService.log('📊 Monitoring service stopped', level: LogLevel.info);
  }

  /// Register an alert callback
  void registerAlertCallback(Function(Alert) callback) {
    _alertCallbacks.add(callback);
  }

  /// Unregister an alert callback
  void unregisterAlertCallback(Function(Alert) callback) {
    _alertCallbacks.remove(callback);
  }

  /// Get success rate for all file operations
  double getOverallSuccessRate() {
    return _logService.getFileOperationSuccessRate();
  }

  /// Get success rate for a specific operation
  double getOperationSuccessRate(String operation) {
    final logs = _logService.getFileOperationLogs();
    final operationLogs = logs.where((log) => log.operation == operation);

    if (operationLogs.isEmpty) return 1.0;

    final successCount =
        operationLogs.where((log) => log.outcome == 'success').length;
    return successCount / operationLogs.length;
  }

  /// Get failure rate for all file operations
  double getOverallFailureRate() {
    return 1.0 - getOverallSuccessRate();
  }

  /// Get failure rate for a specific operation
  double getOperationFailureRate(String operation) {
    return 1.0 - getOperationSuccessRate(operation);
  }

  /// Get average operation duration
  Duration? getAverageOperationDuration(String operation) {
    return _logService.getAverageOperationDuration(operation);
  }

  /// Get error count in the last N minutes
  int getRecentErrorCount(int minutes) {
    final recentLogs = _logService.getRecentFileOperationLogs(minutes);
    return recentLogs.where((log) => log.outcome == 'failure').length;
  }

  /// Get slow operations count in the last N minutes
  int getRecentSlowOperationsCount(int minutes) {
    final recentMetrics = _logService.getRecentPerformanceMetrics(minutes);
    return recentMetrics
        .where((metric) =>
            metric.duration.inMilliseconds > slowOperationThresholdMs)
        .length;
  }

  /// Get operation metrics for a specific operation
  OperationMetrics getOperationMetrics(String operation) {
    if (!_operationMetrics.containsKey(operation)) {
      _operationMetrics[operation] = _calculateOperationMetrics(operation);
    }
    return _operationMetrics[operation]!;
  }

  /// Get all operation metrics
  Map<String, OperationMetrics> getAllOperationMetrics() {
    // Get unique operations
    final operations =
        _logService.getFileOperationLogs().map((log) => log.operation).toSet();

    // Calculate metrics for each operation
    final metrics = <String, OperationMetrics>{};
    for (final operation in operations) {
      metrics[operation] = getOperationMetrics(operation);
    }

    return metrics;
  }

  /// Get monitoring dashboard data
  MonitoringDashboard getDashboard() {
    final stats = _logService.getStatistics();
    final recentLogs = _logService.getRecentFileOperationLogs(60);
    final recentMetrics = _logService.getRecentPerformanceMetrics(60);

    return MonitoringDashboard(
      overallSuccessRate: getOverallSuccessRate(),
      totalOperations: stats.totalFileOperationLogs,
      recentOperations: recentLogs.length,
      recentErrors: getRecentErrorCount(60),
      recentSlowOperations: getRecentSlowOperationsCount(60),
      averageResponseTime: _calculateAverageResponseTime(recentMetrics),
      operationMetrics: getAllOperationMetrics(),
      recentAlerts: getRecentAlerts(60),
      timestamp: DateTime.now(),
    );
  }

  /// Get recent alerts
  List<Alert> getRecentAlerts(int minutes) {
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    return _alerts.where((alert) => alert.timestamp.isAfter(cutoff)).toList();
  }

  /// Get all alerts
  List<Alert> getAllAlerts() {
    return _alerts.toList();
  }

  /// Get alerts by severity
  List<Alert> getAlertsBySeverity(AlertSeverity severity) {
    return _alerts.where((alert) => alert.severity == severity).toList();
  }

  /// Clear all alerts
  void clearAlerts() {
    _alerts.clear();
    _logService.log('🧹 Monitoring alerts cleared', level: LogLevel.info);
  }

  /// Clear operation metrics cache
  void clearMetricsCache() {
    _operationMetrics.clear();
  }

  /// Manually trigger metrics check
  void checkMetrics() {
    _checkMetrics();
  }

  // Private methods

  void _checkMetrics() {
    _clearMetricsCache();

    // Check overall success rate
    final successRate = getOverallSuccessRate();
    if (successRate < successRateThreshold) {
      _createAlert(
        type: AlertType.lowSuccessRate,
        severity: AlertSeverity.warning,
        message:
            'Overall success rate (${(successRate * 100).toStringAsFixed(1)}%) is below threshold (${(successRateThreshold * 100).toStringAsFixed(1)}%)',
        metadata: {
          'successRate': successRate,
          'threshold': successRateThreshold
        },
      );
    }

    // Check error rate
    final errorCount = getRecentErrorCount(60);
    if (errorCount > errorRateThresholdPerHour) {
      _createAlert(
        type: AlertType.highErrorRate,
        severity: AlertSeverity.error,
        message:
            'High error rate detected: $errorCount errors in the last hour (threshold: $errorRateThresholdPerHour)',
        metadata: {
          'errorCount': errorCount,
          'threshold': errorRateThresholdPerHour
        },
      );
    }

    // Check slow operations
    final slowOpsCount = getRecentSlowOperationsCount(60);
    if (slowOpsCount > 5) {
      _createAlert(
        type: AlertType.slowOperations,
        severity: AlertSeverity.warning,
        message:
            'Multiple slow operations detected: $slowOpsCount operations took longer than ${slowOperationThresholdMs}ms',
        metadata: {
          'slowOperationsCount': slowOpsCount,
          'threshold': slowOperationThresholdMs
        },
      );
    }

    // Check individual operation metrics
    final operations =
        _logService.getFileOperationLogs().map((log) => log.operation).toSet();

    for (final operation in operations) {
      final opSuccessRate = getOperationSuccessRate(operation);
      if (opSuccessRate < successRateThreshold) {
        _createAlert(
          type: AlertType.operationFailure,
          severity: AlertSeverity.warning,
          message:
              'Operation "$operation" has low success rate: ${(opSuccessRate * 100).toStringAsFixed(1)}%',
          metadata: {
            'operation': operation,
            'successRate': opSuccessRate,
            'threshold': successRateThreshold
          },
        );
      }

      final avgDuration = getAverageOperationDuration(operation);
      if (avgDuration != null &&
          avgDuration.inMilliseconds > slowOperationThresholdMs) {
        _createAlert(
          type: AlertType.slowOperations,
          severity: AlertSeverity.info,
          message:
              'Operation "$operation" has high average duration: ${avgDuration.inMilliseconds}ms',
          metadata: {
            'operation': operation,
            'averageDuration': avgDuration.inMilliseconds,
            'threshold': slowOperationThresholdMs
          },
        );
      }
    }
  }

  void _createAlert({
    required AlertType type,
    required AlertSeverity severity,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    final alert = Alert(
      type: type,
      severity: severity,
      message: message,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _alerts.add(alert);

    // Keep only the last maxAlerts
    while (_alerts.length > maxAlerts) {
      _alerts.removeFirst();
    }

    // Log the alert
    final logLevel = severity == AlertSeverity.error
        ? LogLevel.error
        : severity == AlertSeverity.warning
            ? LogLevel.warning
            : LogLevel.info;

    _logService.log('🚨 ALERT [${severity.name.toUpperCase()}]: $message',
        level: logLevel);

    // Trigger callbacks
    for (final callback in _alertCallbacks) {
      try {
        callback(alert);
      } catch (e) {
        _logService.log('❌ Error in alert callback: $e', level: LogLevel.error);
      }
    }
  }

  OperationMetrics _calculateOperationMetrics(String operation) {
    final logs = _logService.getFileOperationLogs();
    final operationLogs = logs.where((log) => log.operation == operation);

    if (operationLogs.isEmpty) {
      return OperationMetrics(
        operation: operation,
        totalCount: 0,
        successCount: 0,
        failureCount: 0,
        successRate: 0.0,
        averageDuration: null,
        minDuration: null,
        maxDuration: null,
        totalDataProcessed: 0,
      );
    }

    final successCount =
        operationLogs.where((log) => log.outcome == 'success').length;
    final failureCount = operationLogs.length - successCount;

    // Get performance metrics for this operation
    final perfMetrics = _logService.getPerformanceMetricsByOperation(operation);

    Duration? avgDuration;
    Duration? minDuration;
    Duration? maxDuration;
    int totalDataProcessed = 0;

    if (perfMetrics.isNotEmpty) {
      final durations = perfMetrics.map((m) => m.duration).toList();
      durations.sort((a, b) => a.compareTo(b));

      minDuration = durations.first;
      maxDuration = durations.last;

      final totalMicroseconds =
          durations.fold<int>(0, (sum, d) => sum + d.inMicroseconds);
      avgDuration =
          Duration(microseconds: totalMicroseconds ~/ durations.length);

      totalDataProcessed =
          perfMetrics.fold<int>(0, (sum, m) => sum + (m.dataSizeBytes ?? 0));
    }

    return OperationMetrics(
      operation: operation,
      totalCount: operationLogs.length,
      successCount: successCount,
      failureCount: failureCount,
      successRate: successCount / operationLogs.length,
      averageDuration: avgDuration,
      minDuration: minDuration,
      maxDuration: maxDuration,
      totalDataProcessed: totalDataProcessed,
    );
  }

  Duration? _calculateAverageResponseTime(List<PerformanceMetric> metrics) {
    if (metrics.isEmpty) return null;

    final totalMicroseconds =
        metrics.fold<int>(0, (sum, m) => sum + m.duration.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ metrics.length);
  }

  void _clearMetricsCache() {
    _operationMetrics.clear();
  }
}

/// Alert model
class Alert {
  final AlertType type;
  final AlertSeverity severity;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  Alert({
    required this.type,
    required this.severity,
    required this.message,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() {
    return '[${severity.name.toUpperCase()}] ${type.name}: $message at ${timestamp.toIso8601String()}';
  }
}

/// Alert types
enum AlertType {
  lowSuccessRate,
  highErrorRate,
  slowOperations,
  operationFailure,
  performanceDegradation,
  systemError,
}

/// Alert severity levels
enum AlertSeverity {
  info,
  warning,
  error,
  critical,
}

/// Operation metrics model
class OperationMetrics {
  final String operation;
  final int totalCount;
  final int successCount;
  final int failureCount;
  final double successRate;
  final Duration? averageDuration;
  final Duration? minDuration;
  final Duration? maxDuration;
  final int totalDataProcessed;

  OperationMetrics({
    required this.operation,
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
    required this.successRate,
    this.averageDuration,
    this.minDuration,
    this.maxDuration,
    required this.totalDataProcessed,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Operation: $operation');
    buffer.writeln('  Total: $totalCount');
    buffer.writeln('  Success: $successCount');
    buffer.writeln('  Failure: $failureCount');
    buffer
        .writeln('  Success Rate: ${(successRate * 100).toStringAsFixed(1)}%');

    if (averageDuration != null) {
      buffer.writeln('  Avg Duration: ${averageDuration!.inMilliseconds}ms');
    }
    if (minDuration != null) {
      buffer.writeln('  Min Duration: ${minDuration!.inMilliseconds}ms');
    }
    if (maxDuration != null) {
      buffer.writeln('  Max Duration: ${maxDuration!.inMilliseconds}ms');
    }
    if (totalDataProcessed > 0) {
      buffer.writeln('  Total Data: ${_formatBytes(totalDataProcessed)}');
    }

    return buffer.toString().trimRight();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// Monitoring dashboard model
class MonitoringDashboard {
  final double overallSuccessRate;
  final int totalOperations;
  final int recentOperations;
  final int recentErrors;
  final int recentSlowOperations;
  final Duration? averageResponseTime;
  final Map<String, OperationMetrics> operationMetrics;
  final List<Alert> recentAlerts;
  final DateTime timestamp;

  MonitoringDashboard({
    required this.overallSuccessRate,
    required this.totalOperations,
    required this.recentOperations,
    required this.recentErrors,
    required this.recentSlowOperations,
    this.averageResponseTime,
    required this.operationMetrics,
    required this.recentAlerts,
    required this.timestamp,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('=== Monitoring Dashboard ===');
    buffer.writeln('Timestamp: ${timestamp.toIso8601String()}');
    buffer.writeln('');
    buffer.writeln('Overall Metrics:');
    buffer.writeln(
        '  Success Rate: ${(overallSuccessRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Total Operations: $totalOperations');
    buffer.writeln('  Recent Operations (1h): $recentOperations');
    buffer.writeln('  Recent Errors (1h): $recentErrors');
    buffer.writeln('  Recent Slow Operations (1h): $recentSlowOperations');

    if (averageResponseTime != null) {
      buffer.writeln(
          '  Avg Response Time: ${averageResponseTime!.inMilliseconds}ms');
    }

    if (recentAlerts.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Recent Alerts (${recentAlerts.length}):');
      for (final alert in recentAlerts.take(5)) {
        buffer.writeln('  - ${alert.severity.name}: ${alert.message}');
      }
    }

    if (operationMetrics.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Operation Metrics:');
      for (final entry in operationMetrics.entries) {
        buffer.writeln('  ${entry.key}:');
        buffer.writeln(
            '    Success Rate: ${(entry.value.successRate * 100).toStringAsFixed(1)}%');
        buffer.writeln('    Total: ${entry.value.totalCount}');
        if (entry.value.averageDuration != null) {
          buffer.writeln(
              '    Avg Duration: ${entry.value.averageDuration!.inMilliseconds}ms');
        }
      }
    }

    return buffer.toString();
  }
}
