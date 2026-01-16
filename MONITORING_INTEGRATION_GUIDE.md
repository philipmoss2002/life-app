# Monitoring Integration Guide

This guide shows how to integrate the monitoring and alerting system into your application.

## Quick Start

### 1. Start Monitoring on App Launch

```dart
import 'package:household_docs_app/services/monitoring_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Amplify and other services...
  
  // Start monitoring service
  MonitoringService().startMonitoring();
  
  runApp(MyApp());
}
```

### 2. Add Dashboard to Your App

```dart
import 'package:household_docs_app/widgets/monitoring_dashboard_widget.dart';

class MonitoringScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('System Monitoring'),
      ),
      body: MonitoringDashboardWidget(
        refreshInterval: Duration(seconds: 30),
      ),
    );
  }
}
```

### 3. Configure Alert Callbacks

```dart
void setupMonitoring() {
  final monitoring = MonitoringService();
  
  // Register alert callback
  monitoring.registerAlertCallback((alert) {
    print('🚨 Alert: ${alert.severity.name} - ${alert.message}');
    
    // Handle critical alerts
    if (alert.severity == AlertSeverity.critical) {
      // Send notification, log to analytics, etc.
      _handleCriticalAlert(alert);
    }
  });
  
  // Start monitoring
  monitoring.startMonitoring();
}
```

## Configuration

### Custom Thresholds

```dart
void configureMonitoring() {
  final monitoring = MonitoringService();
  
  // Success rate threshold (default: 0.90 = 90%)
  monitoring.successRateThreshold = 0.95; // 95%
  
  // Slow operation threshold (default: 5000ms)
  monitoring.slowOperationThresholdMs = 3000; // 3 seconds
  
  // Error rate threshold (default: 10 per hour)
  monitoring.errorRateThresholdPerHour = 5;
  
  // Monitoring interval (default: 5 minutes)
  monitoring.monitoringInterval = Duration(minutes: 10);
  
  // Max alerts to keep (default: 100)
  monitoring.maxAlerts = 200;
  
  monitoring.startMonitoring();
}
```

## Usage Examples

### Example 1: Check System Health

```dart
void checkSystemHealth() {
  final monitoring = MonitoringService();
  
  // Get overall success rate
  final successRate = monitoring.getOverallSuccessRate();
  print('Success Rate: ${(successRate * 100).toStringAsFixed(1)}%');
  
  // Get failure rate
  final failureRate = monitoring.getOverallFailureRate();
  print('Failure Rate: ${(failureRate * 100).toStringAsFixed(1)}%');
  
  // Check if system is healthy
  if (successRate >= 0.95) {
    print('✅ System is healthy');
  } else if (successRate >= 0.90) {
    print('⚠️ System performance is acceptable');
  } else {
    print('❌ System needs attention');
  }
}
```

### Example 2: Monitor Specific Operations

```dart
void monitorUploadPerformance() {
  final monitoring = MonitoringService();
  
  // Get upload operation metrics
  final uploadMetrics = monitoring.getOperationMetrics('uploadFile');
  
  print('Upload Metrics:');
  print('  Total: ${uploadMetrics.totalCount}');
  print('  Success: ${uploadMetrics.successCount}');
  print('  Failure: ${uploadMetrics.failureCount}');
  print('  Success Rate: ${(uploadMetrics.successRate * 100).toStringAsFixed(1)}%');
  
  if (uploadMetrics.averageDuration != null) {
    print('  Avg Duration: ${uploadMetrics.averageDuration!.inMilliseconds}ms');
  }
  
  // Check if uploads are performing well
  if (uploadMetrics.successRate < 0.90) {
    print('⚠️ Upload success rate is low!');
  }
  
  if (uploadMetrics.averageDuration != null && 
      uploadMetrics.averageDuration!.inMilliseconds > 5000) {
    print('⚠️ Uploads are slow!');
  }
}
```

### Example 3: Get Recent Errors

```dart
void checkRecentErrors() {
  final monitoring = MonitoringService();
  
  // Get error count in last hour
  final errorCount = monitoring.getRecentErrorCount(60);
  print('Errors in last hour: $errorCount');
  
  // Get slow operations count
  final slowOps = monitoring.getRecentSlowOperationsCount(60);
  print('Slow operations in last hour: $slowOps');
  
  // Get recent alerts
  final alerts = monitoring.getRecentAlerts(60);
  print('Recent alerts: ${alerts.length}');
  
  for (final alert in alerts) {
    print('  - [${alert.severity.name}] ${alert.message}');
  }
}
```

### Example 4: Display Dashboard Data

```dart
void displayDashboard() {
  final monitoring = MonitoringService();
  final dashboard = monitoring.getDashboard();
  
  print(dashboard); // Formatted output
  
  // Or access individual fields
  print('Overall Success Rate: ${(dashboard.overallSuccessRate * 100).toStringAsFixed(1)}%');
  print('Total Operations: ${dashboard.totalOperations}');
  print('Recent Operations (1h): ${dashboard.recentOperations}');
  print('Recent Errors (1h): ${dashboard.recentErrors}');
  print('Recent Slow Operations (1h): ${dashboard.recentSlowOperations}');
  
  if (dashboard.averageResponseTime != null) {
    print('Avg Response Time: ${dashboard.averageResponseTime!.inMilliseconds}ms');
  }
  
  print('\nOperation Metrics:');
  for (final entry in dashboard.operationMetrics.entries) {
    print('  ${entry.key}: ${(entry.value.successRate * 100).toStringAsFixed(1)}%');
  }
  
  print('\nRecent Alerts: ${dashboard.recentAlerts.length}');
  for (final alert in dashboard.recentAlerts) {
    print('  - ${alert}');
  }
}
```

### Example 5: Alert Notifications

```dart
void setupAlertNotifications(BuildContext context) {
  MonitoringService().registerAlertCallback((alert) {
    // Show snackbar for warnings
    if (alert.severity == AlertSeverity.warning) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(alert.message),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
    
    // Show dialog for errors
    if (alert.severity == AlertSeverity.error || 
        alert.severity == AlertSeverity.critical) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 8),
              Text('System Alert'),
            ],
          ),
          content: Text(alert.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to monitoring dashboard
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text('Monitoring')),
                      body: MonitoringDashboardWidget(),
                    ),
                  ),
                );
              },
              child: Text('View Details'),
            ),
          ],
        ),
      );
    }
  });
}
```

### Example 6: Manual Metrics Check

```dart
void performManualCheck() {
  final monitoring = MonitoringService();
  
  // Trigger manual metrics check
  monitoring.checkMetrics();
  
  // Get alerts generated by the check
  final alerts = monitoring.getRecentAlerts(1); // Last 1 minute
  
  if (alerts.isEmpty) {
    print('✅ No issues detected');
  } else {
    print('⚠️ ${alerts.length} issues detected:');
    for (final alert in alerts) {
      print('  - ${alert}');
    }
  }
}
```

### Example 7: Export Metrics

```dart
Future<void> exportMetrics() async {
  final monitoring = MonitoringService();
  final dashboard = monitoring.getDashboard();
  
  // Create metrics report
  final report = StringBuffer();
  report.writeln('=== Monitoring Report ===');
  report.writeln('Generated: ${DateTime.now().toIso8601String()}');
  report.writeln('');
  report.writeln(dashboard.toString());
  
  // Save to file or send to server
  final file = File('monitoring_report.txt');
  await file.writeAsString(report.toString());
  
  print('Report exported to: ${file.path}');
}
```

## Integration with Settings

### Add Monitoring to Settings Screen

```dart
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          // Monitoring section
          ListTile(
            leading: Icon(Icons.analytics),
            title: Text('System Monitoring'),
            subtitle: Text('View performance metrics and alerts'),
            trailing: Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: Text('Monitoring')),
                    body: MonitoringDashboardWidget(),
                  ),
                ),
              );
            },
          ),
          
          // Quick health check
          ListTile(
            leading: Icon(Icons.health_and_safety),
            title: Text('System Health'),
            subtitle: FutureBuilder<double>(
              future: Future.value(MonitoringService().getOverallSuccessRate()),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Text('Loading...');
                final rate = snapshot.data!;
                final color = rate >= 0.95 ? Colors.green : 
                             rate >= 0.90 ? Colors.orange : Colors.red;
                return Text(
                  'Success Rate: ${(rate * 100).toStringAsFixed(1)}%',
                  style: TextStyle(color: color),
                );
              },
            ),
            onTap: () {
              _showHealthDialog(context);
            },
          ),
          
          // Other settings...
        ],
      ),
    );
  }
  
  void _showHealthDialog(BuildContext context) {
    final monitoring = MonitoringService();
    final successRate = monitoring.getOverallSuccessRate();
    final errorCount = monitoring.getRecentErrorCount(60);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('System Health'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Success Rate: ${(successRate * 100).toStringAsFixed(1)}%'),
            Text('Recent Errors: $errorCount'),
            SizedBox(height: 16),
            Text(
              successRate >= 0.95 ? '✅ System is healthy' :
              successRate >= 0.90 ? '⚠️ System is acceptable' :
              '❌ System needs attention',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}
```

## Best Practices

### 1. Start Monitoring Early

```dart
// ✅ Good - Start on app launch
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MonitoringService().startMonitoring();
  runApp(MyApp());
}

// ❌ Avoid - Starting too late
void someFunction() {
  MonitoringService().startMonitoring(); // Too late
}
```

### 2. Configure Thresholds Based on Your Needs

```dart
// ✅ Good - Configure for your use case
monitoring.successRateThreshold = 0.98; // High-reliability app
monitoring.slowOperationThresholdMs = 2000; // Fast operations required

// ❌ Avoid - Using defaults without consideration
// Default thresholds may not match your requirements
```

### 3. Handle Alerts Appropriately

```dart
// ✅ Good - Different handling for different severities
monitoring.registerAlertCallback((alert) {
  switch (alert.severity) {
    case AlertSeverity.info:
      print('ℹ️ ${alert.message}');
      break;
    case AlertSeverity.warning:
      showSnackBar(alert.message);
      break;
    case AlertSeverity.error:
      showDialog(alert.message);
      logToAnalytics(alert);
      break;
    case AlertSeverity.critical:
      showDialog(alert.message);
      logToAnalytics(alert);
      sendToMonitoringService(alert);
      break;
  }
});

// ❌ Avoid - Ignoring alerts
monitoring.registerAlertCallback((alert) {
  // Do nothing
});
```

### 4. Monitor Regularly

```dart
// ✅ Good - Automatic monitoring
monitoring.startMonitoring(); // Checks every 5 minutes

// ❌ Avoid - Only manual checks
// Manual checks may miss issues
```

### 5. Display Dashboard for Users

```dart
// ✅ Good - Make monitoring visible
// Add to settings or admin panel
ListTile(
  title: Text('System Monitoring'),
  onTap: () => Navigator.push(...),
)

// ❌ Avoid - Hiding monitoring completely
// Users should be able to see system health
```

## Troubleshooting

### No Alerts Being Triggered

Check if monitoring is started:
```dart
// Start monitoring
MonitoringService().startMonitoring();

// Or trigger manual check
MonitoringService().checkMetrics();
```

### Thresholds Too Sensitive

Adjust thresholds:
```dart
monitoring.successRateThreshold = 0.85; // Lower threshold
monitoring.errorRateThresholdPerHour = 20; // Higher threshold
```

### Dashboard Not Updating

Check refresh interval:
```dart
MonitoringDashboardWidget(
  refreshInterval: Duration(seconds: 10), // Faster refresh
)
```

### Too Many Alerts

Increase thresholds or clear old alerts:
```dart
// Clear alerts
monitoring.clearAlerts();

// Adjust thresholds
monitoring.successRateThreshold = 0.85;
```

## Summary

The monitoring and alerting system provides:

- ✅ Real-time success/failure rate monitoring
- ✅ Performance threshold alerting
- ✅ Comprehensive dashboard UI
- ✅ Configurable thresholds
- ✅ Alert callbacks for custom handling
- ✅ Per-operation metrics
- ✅ Automatic and manual monitoring

Use `MonitoringService` for programmatic access and `MonitoringDashboardWidget` for UI display.
