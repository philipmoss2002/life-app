import 'dart:developer' as developer;

/// Performance monitoring service for tracking sync operation metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Map<String, DateTime> _operationStartTimes = {};
  final List<OperationMetric> _metrics = [];
  final Map<String, int> _successCounts = {};
  final Map<String, int> _failureCounts = {};
  final Map<String, List<Duration>> _latencies = {};
  final Map<String, int> _bandwidthUsage = {};

  /// Start tracking an operation
  void startOperation(String operationId, String operationType) {
    _operationStartTimes[operationId] = DateTime.now();
    developer.log('Started operation: $operationType',
        name: 'PerformanceMonitor');
  }

  /// End tracking an operation with success
  void endOperationSuccess(String operationId, String operationType,
      {int? bytesTransferred}) {
    final startTime = _operationStartTimes.remove(operationId);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);

    // Track success count
    _successCounts[operationType] = (_successCounts[operationType] ?? 0) + 1;

    // Track latency
    _latencies.putIfAbsent(operationType, () => []).add(duration);

    // Track bandwidth if provided
    if (bytesTransferred != null) {
      _bandwidthUsage[operationType] =
          (_bandwidthUsage[operationType] ?? 0) + bytesTransferred;
    }

    // Create metric record
    final metric = OperationMetric(
      operationType: operationType,
      operationId: operationId,
      duration: duration,
      success: true,
      timestamp: DateTime.now(),
      bytesTransferred: bytesTransferred,
    );

    _metrics.add(metric);

    developer.log(
        'Operation completed successfully: $operationType (${duration.inMilliseconds}ms)',
        name: 'PerformanceMonitor');

    // Alert if operation is slow (>5 seconds)
    if (duration.inSeconds > 5) {
      _logSlowOperation(operationType, duration);
    }
  }

  /// End tracking an operation with failure
  void endOperationFailure(
      String operationId, String operationType, String error,
      {int? bytesTransferred}) {
    final startTime = _operationStartTimes.remove(operationId);
    if (startTime == null) return;

    final duration = DateTime.now().difference(startTime);

    // Track failure count
    _failureCounts[operationType] = (_failureCounts[operationType] ?? 0) + 1;

    // Track bandwidth if provided (partial transfer)
    if (bytesTransferred != null) {
      _bandwidthUsage[operationType] =
          (_bandwidthUsage[operationType] ?? 0) + bytesTransferred;
    }

    // Create metric record
    final metric = OperationMetric(
      operationType: operationType,
      operationId: operationId,
      duration: duration,
      success: false,
      timestamp: DateTime.now(),
      error: error,
      bytesTransferred: bytesTransferred,
    );

    _metrics.add(metric);

    developer.log(
        'Operation failed: $operationType - $error (${duration.inMilliseconds}ms)',
        name: 'PerformanceMonitor');
  }

  /// Get success rate for an operation type
  double getSuccessRate(String operationType) {
    final successes = _successCounts[operationType] ?? 0;
    final failures = _failureCounts[operationType] ?? 0;
    final total = successes + failures;

    if (total == 0) return 0.0;
    return successes / total;
  }

  /// Get average latency for an operation type
  Duration? getAverageLatency(String operationType) {
    final latencies = _latencies[operationType];
    if (latencies == null || latencies.isEmpty) return null;

    final totalMs = latencies.fold<int>(
        0, (sum, duration) => sum + duration.inMilliseconds);
    return Duration(milliseconds: (totalMs / latencies.length).round());
  }

  /// Get total bandwidth usage for an operation type
  int getBandwidthUsage(String operationType) {
    return _bandwidthUsage[operationType] ?? 0;
  }

  /// Get all metrics for analysis
  List<OperationMetric> getMetrics({String? operationType, DateTime? since}) {
    var filteredMetrics = _metrics.where((metric) {
      if (operationType != null && metric.operationType != operationType) {
        return false;
      }
      if (since != null && metric.timestamp.isBefore(since)) {
        return false;
      }
      return true;
    }).toList();

    return filteredMetrics;
  }

  /// Get performance summary
  PerformanceSummary getSummary() {
    final now = DateTime.now();
    final lastHour = now.subtract(const Duration(hours: 1));
    final recentMetrics = getMetrics(since: lastHour);

    return PerformanceSummary(
      totalOperations: _metrics.length,
      recentOperations: recentMetrics.length,
      operationTypes: _successCounts.keys.toList(),
      successRates: Map.fromEntries(_successCounts.keys
          .map((type) => MapEntry(type, getSuccessRate(type)))),
      averageLatencies: Map.fromEntries(_latencies.keys
          .map((type) => MapEntry(type, getAverageLatency(type)))),
      bandwidthUsage: Map.from(_bandwidthUsage),
      timestamp: now,
    );
  }

  /// Clear old metrics (keep last 1000 entries)
  void cleanupMetrics() {
    if (_metrics.length > 1000) {
      _metrics.removeRange(0, _metrics.length - 1000);
    }
  }

  /// Clear all metrics (for testing purposes)
  void clearAllMetrics() {
    _metrics.clear();
    _successCounts.clear();
    _failureCounts.clear();
    _latencies.clear();
    _bandwidthUsage.clear();
    _operationStartTimes.clear();
  }

  /// Clear user-specific performance data for user isolation
  /// Called when user signs out to prevent performance data leakage between users
  void clearUserPerformanceData() {
    try {
      // Clear all performance metrics and state
      _metrics.clear();
      _successCounts.clear();
      _failureCounts.clear();
      _latencies.clear();
      _bandwidthUsage.clear();
      _operationStartTimes.clear();

      developer.log('Performance data cleared for user isolation',
          name: 'PerformanceMonitor');
    } catch (e) {
      developer.log('Error clearing user performance data: $e',
          name: 'PerformanceMonitor');
    }
  }

  /// Reset performance monitor for new user session
  /// Called when a new user signs in to ensure clean performance tracking
  void resetForNewUser() {
    clearUserPerformanceData();
    developer.log('Performance monitor reset for new user session',
        name: 'PerformanceMonitor');
  }

  void _logSlowOperation(String operationType, Duration duration) {
    developer.log(
      'SLOW OPERATION DETECTED: $operationType took ${duration.inSeconds}s',
      name: 'PerformanceMonitor',
      level: 900, // Warning level
    );
  }
}

/// Represents a single operation metric
class OperationMetric {
  final String operationType;
  final String operationId;
  final Duration duration;
  final bool success;
  final DateTime timestamp;
  final String? error;
  final int? bytesTransferred;

  const OperationMetric({
    required this.operationType,
    required this.operationId,
    required this.duration,
    required this.success,
    required this.timestamp,
    this.error,
    this.bytesTransferred,
  });

  Map<String, dynamic> toJson() {
    return {
      'operationType': operationType,
      'operationId': operationId,
      'durationMs': duration.inMilliseconds,
      'success': success,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'bytesTransferred': bytesTransferred,
    };
  }
}

/// Performance summary for analytics
class PerformanceSummary {
  final int totalOperations;
  final int recentOperations;
  final List<String> operationTypes;
  final Map<String, double> successRates;
  final Map<String, Duration?> averageLatencies;
  final Map<String, int> bandwidthUsage;
  final DateTime timestamp;

  const PerformanceSummary({
    required this.totalOperations,
    required this.recentOperations,
    required this.operationTypes,
    required this.successRates,
    required this.averageLatencies,
    required this.bandwidthUsage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalOperations': totalOperations,
      'recentOperations': recentOperations,
      'operationTypes': operationTypes,
      'successRates': successRates,
      'averageLatencies': averageLatencies
          .map((key, value) => MapEntry(key, value?.inMilliseconds)),
      'bandwidthUsage': bandwidthUsage,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
