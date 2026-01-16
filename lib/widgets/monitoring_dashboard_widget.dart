import 'package:flutter/material.dart';
import '../services/monitoring_service.dart';
import 'dart:async';

/// Monitoring dashboard widget for displaying file operation metrics
/// Provides real-time view of success rates, performance, and alerts
class MonitoringDashboardWidget extends StatefulWidget {
  final Duration refreshInterval;

  const MonitoringDashboardWidget({
    super.key,
    this.refreshInterval = const Duration(seconds: 30),
  });

  @override
  State<MonitoringDashboardWidget> createState() =>
      _MonitoringDashboardWidgetState();
}

class _MonitoringDashboardWidgetState extends State<MonitoringDashboardWidget> {
  final MonitoringService _monitoringService = MonitoringService();
  MonitoringDashboard? _dashboard;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadDashboard() {
    setState(() {
      _dashboard = _monitoringService.getDashboard();
    });
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(widget.refreshInterval, (_) {
      _loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dashboard == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadDashboard();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildOverallMetrics(),
            const SizedBox(height: 16),
            _buildRecentAlerts(),
            const SizedBox(height: 16),
            _buildOperationMetrics(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Monitoring Dashboard',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Updated: ${_formatTime(_dashboard!.timestamp)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Success Rate',
                    '${(_dashboard!.overallSuccessRate * 100).toStringAsFixed(1)}%',
                    _getSuccessRateColor(_dashboard!.overallSuccessRate),
                    Icons.check_circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Total Operations',
                    '${_dashboard!.totalOperations}',
                    Colors.blue,
                    Icons.analytics,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    'Recent Errors (1h)',
                    '${_dashboard!.recentErrors}',
                    _dashboard!.recentErrors > 10 ? Colors.red : Colors.orange,
                    Icons.error,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    'Slow Operations (1h)',
                    '${_dashboard!.recentSlowOperations}',
                    _dashboard!.recentSlowOperations > 5
                        ? Colors.orange
                        : Colors.green,
                    Icons.speed,
                  ),
                ),
              ],
            ),
            if (_dashboard!.averageResponseTime != null) ...[
              const SizedBox(height: 8),
              _buildMetricCard(
                'Avg Response Time',
                '${_dashboard!.averageResponseTime!.inMilliseconds}ms',
                Colors.purple,
                Icons.timer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAlerts() {
    if (_dashboard!.recentAlerts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[600]),
              const SizedBox(width: 8),
              const Text(
                'No recent alerts',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_dashboard!.recentAlerts.length} alerts',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._dashboard!.recentAlerts.take(5).map((alert) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAlertItem(alert),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(Alert alert) {
    final color = _getAlertColor(alert.severity);
    final icon = _getAlertIcon(alert.severity);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.severity.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(alert.timestamp),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationMetrics() {
    if (_dashboard!.operationMetrics.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No operation metrics available'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operation Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._dashboard!.operationMetrics.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOperationMetricItem(entry.key, entry.value),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationMetricItem(String operation, OperationMetrics metrics) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                operation,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSuccessRateColor(metrics.successRate),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(metrics.successRate * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSmallMetric(
                    'Total', '${metrics.totalCount}', Colors.blue),
              ),
              Expanded(
                child: _buildSmallMetric(
                    'Success', '${metrics.successCount}', Colors.green),
              ),
              Expanded(
                child: _buildSmallMetric(
                    'Failure', '${metrics.failureCount}', Colors.red),
              ),
            ],
          ),
          if (metrics.averageDuration != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSmallMetric(
                    'Avg',
                    '${metrics.averageDuration!.inMilliseconds}ms',
                    Colors.purple,
                  ),
                ),
                if (metrics.minDuration != null)
                  Expanded(
                    child: _buildSmallMetric(
                      'Min',
                      '${metrics.minDuration!.inMilliseconds}ms',
                      Colors.teal,
                    ),
                  ),
                if (metrics.maxDuration != null)
                  Expanded(
                    child: _buildSmallMetric(
                      'Max',
                      '${metrics.maxDuration!.inMilliseconds}ms',
                      Colors.orange,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSmallMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getSuccessRateColor(double rate) {
    if (rate >= 0.95) return Colors.green;
    if (rate >= 0.90) return Colors.lightGreen;
    if (rate >= 0.80) return Colors.orange;
    return Colors.red;
  }

  Color _getAlertColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return Colors.blue;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.error:
        return Colors.red;
      case AlertSeverity.critical:
        return Colors.purple;
    }
  }

  IconData _getAlertIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.info:
        return Icons.info;
      case AlertSeverity.warning:
        return Icons.warning;
      case AlertSeverity.error:
        return Icons.error;
      case AlertSeverity.critical:
        return Icons.dangerous;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
