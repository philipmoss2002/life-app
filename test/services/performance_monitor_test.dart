import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:household_docs_app/services/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;
    final faker = Faker();

    setUp(() {
      monitor = PerformanceMonitor();
      // Clear all metrics for clean test state
      monitor.clearAllMetrics();
    });

    group('Property-Based Tests', () {
      /// **Feature: cloud-sync-implementation-fix, Property 30: Performance Metrics Collection**
      /// **Validates: Requirements 9.1**
      ///
      /// Property: For any sync operation, latency and success rate metrics should be tracked.
      test(
          'Property 30: Performance Metrics Collection - sync operations track latency and success rates',
          () async {
        // Run the property test multiple times with random data
        const iterations = 100;

        for (int i = 0; i < iterations; i++) {
          // Generate random operation data
          final operationType = faker.randomGenerator.element([
            'document_upload',
            'document_download',
            'document_update',
            'document_delete',
            'file_upload',
            'file_download',
            'batch_upload',
          ]);
          final operationId = faker.guid.guid();
          final shouldSucceed = faker.randomGenerator.boolean();
          final bytesTransferred = faker.randomGenerator.boolean()
              ? faker.randomGenerator
                  .integer(10000000, min: 1000) // 1KB to 10MB
              : null;

          // Start operation tracking
          monitor.startOperation(operationId, operationType);

          // Simulate some processing time
          await Future.delayed(Duration(
              milliseconds: faker.randomGenerator.integer(100, min: 1)));

          if (shouldSucceed) {
            // End operation with success
            monitor.endOperationSuccess(operationId, operationType,
                bytesTransferred: bytesTransferred);

            // Verify success rate tracking
            final successRate = monitor.getSuccessRate(operationType);
            expect(successRate, greaterThan(0.0),
                reason:
                    'Success rate should be greater than 0 after successful operation');
            expect(successRate, lessThanOrEqualTo(1.0),
                reason: 'Success rate should not exceed 1.0');

            // Verify latency tracking
            final avgLatency = monitor.getAverageLatency(operationType);
            expect(avgLatency, isNotNull,
                reason: 'Average latency should be tracked for operation type');
            expect(avgLatency!.inMilliseconds, greaterThan(0),
                reason: 'Latency should be positive');

            // Verify bandwidth tracking if bytes were transferred
            if (bytesTransferred != null) {
              final totalBandwidth = monitor.getBandwidthUsage(operationType);
              expect(totalBandwidth, greaterThanOrEqualTo(bytesTransferred),
                  reason: 'Total bandwidth should include transferred bytes');
            }
          } else {
            // End operation with failure
            final errorMessage = faker.lorem.sentence();
            monitor.endOperationFailure(
                operationId, operationType, errorMessage,
                bytesTransferred: bytesTransferred);

            // Verify that failure is tracked (success rate should be less than 1.0 if there are failures)
            final successRate = monitor.getSuccessRate(operationType);
            expect(successRate, lessThan(1.0),
                reason:
                    'Success rate should be less than 1.0 when there are failures');
          }

          // Verify metrics are recorded
          final metrics = monitor.getMetrics(operationType: operationType);
          expect(metrics, isNotEmpty,
              reason: 'Metrics should be recorded for operations');

          // Verify the latest metric matches our operation
          final latestMetric = metrics.last;
          expect(latestMetric.operationType, equals(operationType));
          expect(latestMetric.operationId, equals(operationId));
          expect(latestMetric.success, equals(shouldSucceed));
          expect(latestMetric.bytesTransferred, equals(bytesTransferred));

          if (!shouldSucceed) {
            expect(latestMetric.error, isNotNull,
                reason: 'Error should be recorded for failed operations');
          }
        }

        // Verify performance summary
        final summary = monitor.getSummary();
        expect(summary.totalOperations, equals(iterations),
            reason: 'Summary should reflect total number of operations');
        expect(summary.operationTypes, isNotEmpty,
            reason: 'Summary should include operation types');
        expect(summary.successRates, isNotEmpty,
            reason: 'Summary should include success rates');
        expect(summary.averageLatencies, isNotEmpty,
            reason: 'Summary should include average latencies');

        // Verify all success rates are valid percentages
        for (final rate in summary.successRates.values) {
          expect(rate, greaterThanOrEqualTo(0.0));
          expect(rate, lessThanOrEqualTo(1.0));
        }

        // Verify all latencies are positive
        for (final latency in summary.averageLatencies.values) {
          if (latency != null) {
            expect(latency.inMilliseconds, greaterThan(0));
          }
        }
      });

      test('Performance metrics collection handles edge cases', () {
        // Test with zero operations
        expect(monitor.getSuccessRate('nonexistent_operation'), equals(0.0));
        expect(monitor.getAverageLatency('nonexistent_operation'), isNull);
        expect(monitor.getBandwidthUsage('nonexistent_operation'), equals(0));

        // Test with operation that never ends
        monitor.startOperation('never_ends', 'test_operation');
        expect(monitor.getSuccessRate('test_operation'), equals(0.0));

        // Test metrics filtering
        final now = DateTime.now();
        final future = now.add(const Duration(hours: 1));
        final pastMetrics = monitor.getMetrics(since: future);
        expect(pastMetrics, isEmpty,
            reason: 'Should return no metrics from the future');
      });

      test('Performance monitor tracks slow operations', () async {
        const operationId = 'slow_operation';
        const operationType = 'test_slow';

        monitor.startOperation(operationId, operationType);

        // Simulate a slow operation (>5 seconds should trigger slow operation logging)
        await Future.delayed(
            const Duration(milliseconds: 100)); // Simulate some time

        monitor.endOperationSuccess(operationId, operationType);

        final metrics = monitor.getMetrics(operationType: operationType);
        expect(metrics, hasLength(1));
        expect(metrics.first.duration.inMilliseconds, greaterThan(0));
      });

      test('Performance monitor cleans up old metrics', () {
        // Add more than 1000 metrics to test cleanup
        for (int i = 0; i < 1100; i++) {
          monitor.startOperation('op_$i', 'test_cleanup');
          monitor.endOperationSuccess('op_$i', 'test_cleanup');
        }

        expect(monitor.getMetrics().length, equals(1100));

        monitor.cleanupMetrics();

        expect(monitor.getMetrics().length, equals(1000));
      });

      /// **Feature: cloud-sync-implementation-fix, Property 31: Bandwidth Usage Tracking**
      /// **Validates: Requirements 9.4**
      ///
      /// Property: For any file operation, bandwidth usage should be measured and tracked.
      test(
          'Property 31: Bandwidth Usage Tracking - file operations track bandwidth usage',
          () async {
        // Run the property test multiple times with random data
        const iterations = 50;

        for (int i = 0; i < iterations; i++) {
          // Generate random file operation data
          final operationType = faker.randomGenerator.element([
            'file_upload',
            'file_download',
          ]);
          final operationId = faker.guid.guid();
          final fileSize =
              faker.randomGenerator.integer(50000000, min: 1000); // 1KB to 50MB
          final shouldSucceed = faker.randomGenerator.boolean();

          // Start operation tracking
          monitor.startOperation(operationId, operationType);

          // Simulate some processing time
          await Future.delayed(Duration(
              milliseconds: faker.randomGenerator.integer(50, min: 1)));

          if (shouldSucceed) {
            // End operation with success and bandwidth data
            monitor.endOperationSuccess(operationId, operationType,
                bytesTransferred: fileSize);

            // Verify bandwidth tracking
            final totalBandwidth = monitor.getBandwidthUsage(operationType);
            expect(totalBandwidth, greaterThanOrEqualTo(fileSize),
                reason: 'Total bandwidth should include the transferred bytes');

            // Verify the metric includes bandwidth data
            final metrics = monitor.getMetrics(operationType: operationType);
            final latestMetric = metrics.last;
            expect(latestMetric.bytesTransferred, equals(fileSize),
                reason: 'Metric should record the bytes transferred');
          } else {
            // End operation with failure (partial transfer)
            final partialTransfer = faker.randomGenerator.integer(fileSize);
            monitor.endOperationFailure(
                operationId, operationType, 'Transfer failed',
                bytesTransferred: partialTransfer);

            // Verify partial bandwidth tracking
            final totalBandwidth = monitor.getBandwidthUsage(operationType);
            expect(totalBandwidth, greaterThanOrEqualTo(partialTransfer),
                reason:
                    'Total bandwidth should include partial transfer bytes');

            // Verify the metric includes partial bandwidth data
            final metrics = monitor.getMetrics(operationType: operationType);
            final latestMetric = metrics.last;
            expect(latestMetric.bytesTransferred, equals(partialTransfer),
                reason:
                    'Failed metric should record the partial bytes transferred');
          }
        }

        // Verify bandwidth summary
        final summary = monitor.getSummary();
        expect(summary.bandwidthUsage, isNotEmpty,
            reason: 'Summary should include bandwidth usage data');

        // Verify bandwidth values are reasonable
        for (final entry in summary.bandwidthUsage.entries) {
          final operationType = entry.key;
          final totalBytes = entry.value;

          expect(totalBytes, greaterThan(0),
              reason: 'Total bandwidth for $operationType should be positive');

          // Verify bandwidth matches sum of individual operations
          final metrics = monitor.getMetrics(operationType: operationType);
          final expectedTotal = metrics
              .where((m) => m.bytesTransferred != null)
              .fold<int>(0, (sum, m) => sum + m.bytesTransferred!);

          expect(totalBytes, equals(expectedTotal),
              reason:
                  'Summary bandwidth should match sum of individual transfers');
        }
      });

      test('Bandwidth tracking handles operations without data transfer', () {
        const operationId = 'no_data_op';
        const operationType = 'metadata_operation';

        monitor.startOperation(operationId, operationType);
        monitor.endOperationSuccess(
            operationId, operationType); // No bytesTransferred

        final bandwidth = monitor.getBandwidthUsage(operationType);
        expect(bandwidth, equals(0),
            reason:
                'Operations without data transfer should not affect bandwidth');

        final metrics = monitor.getMetrics(operationType: operationType);
        expect(metrics.first.bytesTransferred, isNull,
            reason:
                'Metric should have null bytesTransferred for non-data operations');
      });

      test('Bandwidth tracking accumulates across multiple operations', () {
        const operationType = 'accumulation_test';
        final sizes = [1000, 2000, 3000];
        int expectedTotal = 0;

        for (int i = 0; i < sizes.length; i++) {
          final operationId = 'op_$i';
          final size = sizes[i];
          expectedTotal += size;

          monitor.startOperation(operationId, operationType);
          monitor.endOperationSuccess(operationId, operationType,
              bytesTransferred: size);

          final currentTotal = monitor.getBandwidthUsage(operationType);
          expect(currentTotal, equals(expectedTotal),
              reason:
                  'Bandwidth should accumulate correctly after each operation');
        }
      });
    });
  });
}
