import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/log_service.dart';

void main() {
  group('LogService Tests', () {
    late LogService logService;

    setUp(() {
      logService = LogService();
      logService.clearAll();
    });

    tearDown(() {
      logService.clearAll();
    });

    group('Basic Logging', () {
      test('should log messages with different levels', () {
        logService.log('Info message', level: LogLevel.info);
        logService.log('Warning message', level: LogLevel.warning);
        logService.log('Error message', level: LogLevel.error);
        logService.log('Debug message', level: LogLevel.debug);

        final logs = logService.getAllLogs();
        expect(logs.length, 4);
        expect(logs[0].level, LogLevel.info);
        expect(logs[1].level, LogLevel.warning);
        expect(logs[2].level, LogLevel.error);
        expect(logs[3].level, LogLevel.debug);
      });

      test('should filter logs by level', () {
        logService.log('Info 1', level: LogLevel.info);
        logService.log('Error 1', level: LogLevel.error);
        logService.log('Info 2', level: LogLevel.info);
        logService.log('Warning 1', level: LogLevel.warning);

        final errorLogs = logService.getLogsByLevel(LogLevel.error);
        expect(errorLogs.length, 1);
        expect(errorLogs[0].message, 'Error 1');

        final infoLogs = logService.getLogsByLevel(LogLevel.info);
        expect(infoLogs.length, 2);
      });

      test('should include timestamp in log entries', () {
        final before = DateTime.now();
        logService.log('Test message');
        final after = DateTime.now();

        final logs = logService.getAllLogs();
        expect(logs.length, 1);
        expect(logs[0].timestamp.isAfter(before.subtract(Duration(seconds: 1))),
            true);
        expect(
            logs[0].timestamp.isBefore(after.add(Duration(seconds: 1))), true);
      });

      test('should format log entries correctly', () {
        logService.log('Test message', level: LogLevel.info);

        final logs = logService.getAllLogs();
        final formatted = logs[0].toString();

        expect(formatted.contains('INFO'), true);
        expect(formatted.contains('Test message'), true);
      });
    });

    group('File Operation Logging', () {
      test('should log file operations with all fields', () {
        logService.logFileOperation(
          operation: 'uploadFile',
          outcome: 'success',
          userIdentifier: 'user-123',
          syncId: 'sync-456',
          fileName: 'test.pdf',
          s3Key: 'private/user-123/documents/sync-456/test.pdf',
          fileSizeBytes: 1024,
        );

        final logs = logService.getFileOperationLogs();
        expect(logs.length, 1);
        expect(logs[0].operation, 'uploadFile');
        expect(logs[0].outcome, 'success');
        expect(logs[0].userIdentifier, 'user-123');
        expect(logs[0].syncId, 'sync-456');
        expect(logs[0].fileName, 'test.pdf');
        expect(logs[0].fileSizeBytes, 1024);
      });

      test('should log file operation failures with error details', () {
        logService.logFileOperation(
          operation: 'downloadFile',
          outcome: 'failure',
          userIdentifier: 'user-123',
          s3Key: 'private/user-123/documents/sync-456/test.pdf',
          errorCode: 'AccessDenied',
          errorMessage: 'User does not have permission',
          retryAttempt: 2,
        );

        final logs = logService.getFileOperationLogs();
        expect(logs.length, 1);
        expect(logs[0].outcome, 'failure');
        expect(logs[0].errorCode, 'AccessDenied');
        expect(logs[0].errorMessage, 'User does not have permission');
        expect(logs[0].retryAttempt, 2);
      });

      test('should filter file operations by outcome', () {
        logService.logFileOperation(operation: 'upload1', outcome: 'success');
        logService.logFileOperation(operation: 'upload2', outcome: 'failure');
        logService.logFileOperation(operation: 'upload3', outcome: 'success');

        final successLogs = logService.getFileOperationLogsByOutcome('success');
        expect(successLogs.length, 2);

        final failureLogs = logService.getFileOperationLogsByOutcome('failure');
        expect(failureLogs.length, 1);
      });

      test('should filter file operations by user', () {
        logService.logFileOperation(
          operation: 'upload1',
          outcome: 'success',
          userIdentifier: 'user-123',
        );
        logService.logFileOperation(
          operation: 'upload2',
          outcome: 'success',
          userIdentifier: 'user-456',
        );
        logService.logFileOperation(
          operation: 'upload3',
          outcome: 'success',
          userIdentifier: 'user-123',
        );

        final user123Logs = logService.getFileOperationLogsByUser('user-123');
        expect(user123Logs.length, 2);

        final user456Logs = logService.getFileOperationLogsByUser('user-456');
        expect(user456Logs.length, 1);
      });

      test('should format file operation logs correctly', () {
        logService.logFileOperation(
          operation: 'uploadFile',
          outcome: 'success',
          userIdentifier: 'user-123-456-789',
          fileName: 'test.pdf',
          fileSizeBytes: 2048,
        );

        final logs = logService.getFileOperationLogs();
        final formatted = logs[0].toFormattedString();

        expect(formatted.contains('uploadFile'), true);
        expect(formatted.contains('success'), true);
        expect(formatted.contains('user-123'), true); // Masked
        expect(formatted.contains('test.pdf'), true);
        expect(formatted.contains('2.0KB'), true); // Formatted size
      });
    });

    group('Audit Logging', () {
      test('should log audit events with all fields', () {
        logService.logAuditEvent(
          eventType: 'FILE_ACCESS',
          action: 'download',
          userIdentifier: 'user-123',
          resourceId: 's3-key-456',
          outcome: 'success',
          details: 'User downloaded file',
          metadata: {'ipAddress': '192.168.1.1'},
        );

        final logs = logService.getAuditLogs();
        expect(logs.length, 1);
        expect(logs[0].eventType, 'FILE_ACCESS');
        expect(logs[0].action, 'download');
        expect(logs[0].userIdentifier, 'user-123');
        expect(logs[0].resourceId, 's3-key-456');
        expect(logs[0].outcome, 'success');
        expect(logs[0].details, 'User downloaded file');
        expect(logs[0].metadata?['ipAddress'], '192.168.1.1');
      });

      test('should filter audit logs by event type', () {
        logService.logAuditEvent(eventType: 'AUTHENTICATION', action: 'login');
        logService.logAuditEvent(eventType: 'FILE_ACCESS', action: 'download');
        logService.logAuditEvent(eventType: 'AUTHENTICATION', action: 'logout');

        final authLogs = logService.getAuditLogsByEventType('AUTHENTICATION');
        expect(authLogs.length, 2);

        final fileLogs = logService.getAuditLogsByEventType('FILE_ACCESS');
        expect(fileLogs.length, 1);
      });

      test('should filter audit logs by user', () {
        logService.logAuditEvent(
          eventType: 'FILE_ACCESS',
          action: 'download',
          userIdentifier: 'user-123',
        );
        logService.logAuditEvent(
          eventType: 'FILE_ACCESS',
          action: 'upload',
          userIdentifier: 'user-456',
        );
        logService.logAuditEvent(
          eventType: 'FILE_ACCESS',
          action: 'delete',
          userIdentifier: 'user-123',
        );

        final user123Logs = logService.getAuditLogsByUser('user-123');
        expect(user123Logs.length, 2);
      });

      test('should format audit logs correctly', () {
        logService.logAuditEvent(
          eventType: 'FILE_ACCESS',
          action: 'download',
          userIdentifier: 'user-123-456-789',
          outcome: 'success',
        );

        final logs = logService.getAuditLogs();
        final formatted = logs[0].toFormattedString();

        expect(formatted.contains('AUDIT'), true);
        expect(formatted.contains('FILE_ACCESS'), true);
        expect(formatted.contains('download'), true);
        expect(formatted.contains('user-123'), true); // Masked
      });
    });

    group('Performance Metrics', () {
      test('should record performance metrics with all fields', () {
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1500),
          userIdentifier: 'user-123',
          resourceId: 's3-key-456',
          dataSizeBytes: 2048,
          success: true,
          additionalMetrics: {'compressionRatio': 0.75},
        );

        final metrics = logService.getPerformanceMetrics();
        expect(metrics.length, 1);
        expect(metrics[0].operation, 'uploadFile');
        expect(metrics[0].duration.inMilliseconds, 1500);
        expect(metrics[0].userIdentifier, 'user-123');
        expect(metrics[0].dataSizeBytes, 2048);
        expect(metrics[0].success, true);
        expect(metrics[0].additionalMetrics?['compressionRatio'], 0.75);
      });

      test('should filter performance metrics by operation', () {
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1000),
        );
        logService.recordPerformanceMetric(
          operation: 'downloadFile',
          duration: Duration(milliseconds: 2000),
        );
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1500),
        );

        final uploadMetrics =
            logService.getPerformanceMetricsByOperation('uploadFile');
        expect(uploadMetrics.length, 2);

        final downloadMetrics =
            logService.getPerformanceMetricsByOperation('downloadFile');
        expect(downloadMetrics.length, 1);
      });

      test('should calculate average operation duration', () {
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1000),
        );
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 2000),
        );
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 3000),
        );

        final avgDuration =
            logService.getAverageOperationDuration('uploadFile');
        expect(avgDuration, isNotNull);
        expect(avgDuration!.inMilliseconds, 2000);
      });

      test('should return null for average duration with no metrics', () {
        final avgDuration =
            logService.getAverageOperationDuration('nonexistent');
        expect(avgDuration, isNull);
      });

      test('should format performance metrics correctly', () {
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1500),
          dataSizeBytes: 2048,
          success: true,
        );

        final metrics = logService.getPerformanceMetrics();
        final formatted = metrics[0].toFormattedString();

        expect(formatted.contains('uploadFile'), true);
        expect(formatted.contains('1500ms'), true);
        expect(formatted.contains('✓'), true); // Success indicator
      });
    });

    group('Success Rate Calculation', () {
      test('should calculate file operation success rate', () {
        logService.logFileOperation(operation: 'upload1', outcome: 'success');
        logService.logFileOperation(operation: 'upload2', outcome: 'success');
        logService.logFileOperation(operation: 'upload3', outcome: 'failure');
        logService.logFileOperation(operation: 'upload4', outcome: 'success');

        final successRate = logService.getFileOperationSuccessRate();
        expect(successRate, closeTo(0.75, 0.01)); // 3/4 = 0.75
      });

      test('should return 0.0 for success rate with no operations', () {
        final successRate = logService.getFileOperationSuccessRate();
        expect(successRate, 0.0);
      });

      test('should return 1.0 for all successful operations', () {
        logService.logFileOperation(operation: 'upload1', outcome: 'success');
        logService.logFileOperation(operation: 'upload2', outcome: 'success');

        final successRate = logService.getFileOperationSuccessRate();
        expect(successRate, 1.0);
      });

      test('should return 0.0 for all failed operations', () {
        logService.logFileOperation(operation: 'upload1', outcome: 'failure');
        logService.logFileOperation(operation: 'upload2', outcome: 'failure');

        final successRate = logService.getFileOperationSuccessRate();
        expect(successRate, 0.0);
      });
    });

    group('Recent Logs Filtering', () {
      test('should get recent logs within time window', () {
        // Add old log (simulated by clearing and re-adding)
        logService.log('Old log');

        // Wait a bit and add recent logs
        Future.delayed(Duration(milliseconds: 100), () {
          logService.log('Recent log 1');
          logService.log('Recent log 2');
        });

        // Get logs from last 1 minute
        final recentLogs = logService.getRecentLogs(1);
        expect(recentLogs.length, greaterThanOrEqualTo(2));
      });

      test('should get recent file operation logs', () {
        logService.logFileOperation(operation: 'upload1', outcome: 'success');
        logService.logFileOperation(operation: 'upload2', outcome: 'success');

        final recentLogs = logService.getRecentFileOperationLogs(1);
        expect(recentLogs.length, 2);
      });

      test('should get recent audit logs', () {
        logService.logAuditEvent(eventType: 'FILE_ACCESS', action: 'download');
        logService.logAuditEvent(eventType: 'AUTHENTICATION', action: 'login');

        final recentLogs = logService.getRecentAuditLogs(1);
        expect(recentLogs.length, 2);
      });

      test('should get recent performance metrics', () {
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1000),
        );
        logService.recordPerformanceMetric(
          operation: 'downloadFile',
          duration: Duration(milliseconds: 2000),
        );

        final recentMetrics = logService.getRecentPerformanceMetrics(1);
        expect(recentMetrics.length, 2);
      });
    });

    group('Log Management', () {
      test('should clear all logs', () {
        logService.log('Test log');
        logService.logFileOperation(operation: 'upload', outcome: 'success');
        logService.logAuditEvent(eventType: 'FILE_ACCESS', action: 'download');
        logService.recordPerformanceMetric(
          operation: 'upload',
          duration: Duration(milliseconds: 1000),
        );

        logService.clearAll();

        expect(logService.getAllLogs().length, 0);
        expect(logService.getFileOperationLogs().length, 0);
        expect(logService.getAuditLogs().length, 0);
        expect(logService.getPerformanceMetrics().length, 0);
      });

      test('should clear specific log types', () {
        logService.log('Test log');
        logService.logFileOperation(operation: 'upload', outcome: 'success');

        logService.clearFileOperationLogs();

        expect(logService.getAllLogs().length, 1);
        expect(logService.getFileOperationLogs().length, 0);
      });

      test('should get comprehensive statistics', () {
        logService.log('Info', level: LogLevel.info);
        logService.log('Error', level: LogLevel.error);
        logService.log('Warning', level: LogLevel.warning);
        logService.logFileOperation(operation: 'upload1', outcome: 'success');
        logService.logFileOperation(operation: 'upload2', outcome: 'failure');
        logService.logAuditEvent(eventType: 'FILE_ACCESS', action: 'download');
        logService.recordPerformanceMetric(
          operation: 'upload',
          duration: Duration(milliseconds: 1000),
        );

        final stats = logService.getStatistics();

        expect(stats.totalLogs, 3);
        expect(stats.totalFileOperationLogs, 2);
        expect(stats.totalAuditLogs, 1);
        expect(stats.totalPerformanceMetrics, 1);
        expect(stats.fileOperationSuccessRate, 0.5);
        expect(stats.errorCount, 1);
        expect(stats.warningCount, 1);
      });
    });

    group('Formatted Output', () {
      test('should get logs as formatted string', () {
        logService.log('Test message 1');
        logService.log('Test message 2');

        final formatted = logService.getLogsAsString();

        expect(formatted.contains('Test message 1'), true);
        expect(formatted.contains('Test message 2'), true);
      });

      test('should get file operation logs as formatted string', () {
        logService.logFileOperation(
          operation: 'uploadFile',
          outcome: 'success',
          fileName: 'test.pdf',
        );

        final formatted = logService.getFileOperationLogsAsString();

        expect(formatted.contains('uploadFile'), true);
        expect(formatted.contains('success'), true);
        expect(formatted.contains('test.pdf'), true);
      });

      test('should get audit logs as formatted string', () {
        logService.logAuditEvent(
          eventType: 'FILE_ACCESS',
          action: 'download',
        );

        final formatted = logService.getAuditLogsAsString();

        expect(formatted.contains('FILE_ACCESS'), true);
        expect(formatted.contains('download'), true);
      });

      test('should get performance metrics as formatted string', () {
        logService.recordPerformanceMetric(
          operation: 'uploadFile',
          duration: Duration(milliseconds: 1500),
        );

        final formatted = logService.getPerformanceMetricsAsString();

        expect(formatted.contains('uploadFile'), true);
        expect(formatted.contains('1500ms'), true);
      });
    });
  });
}
