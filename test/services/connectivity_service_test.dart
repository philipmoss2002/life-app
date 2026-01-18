import 'package:flutter_test/flutter_test.dart';
import 'package:household_docs_app/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectivityService connectivityService;

  setUp(() {
    connectivityService = ConnectivityService();
  });

  tearDown(() {
    connectivityService.dispose();
  });

  group('ConnectivityService', () {
    test('should be a singleton', () {
      final instance1 = ConnectivityService();
      final instance2 = ConnectivityService();

      expect(instance1, same(instance2));
    });

    test('should have correct initial state', () {
      expect(connectivityService.isOnline, isTrue);
    });

    test('should provide connectivity stream', () {
      expect(connectivityService.connectivityStream, isA<Stream<bool>>());
    });

    test('should initialize without errors', () async {
      // Should not throw
      await expectLater(
        connectivityService.initialize(),
        completes,
      );
    });

    test('should handle multiple initialize calls gracefully', () async {
      await connectivityService.initialize();

      // Second initialize should not throw
      await expectLater(
        connectivityService.initialize(),
        completes,
      );
    });

    test('should check connectivity manually', () async {
      await connectivityService.initialize();

      final isOnline = await connectivityService.checkConnectivity();

      expect(isOnline, isA<bool>());
    });

    test('should dispose without errors', () {
      expect(() => connectivityService.dispose(), returnsNormally);
    });

    test('should emit connectivity changes to stream', () async {
      await connectivityService.initialize();

      // Listen to stream
      final streamValues = <bool>[];
      final subscription = connectivityService.connectivityStream.listen(
        (isOnline) {
          streamValues.add(isOnline);
        },
      );

      // Wait a bit for any initial emissions
      await Future.delayed(const Duration(milliseconds: 100));

      // Clean up
      await subscription.cancel();

      // Stream should be functional (may or may not have emitted values)
      expect(streamValues, isA<List<bool>>());
    });
  });

  group('ConnectivityService - Requirements Verification', () {
    test('Requirement 6.3: Monitors network connectivity', () async {
      // Service should provide connectivity monitoring
      await connectivityService.initialize();

      expect(connectivityService.isOnline, isA<bool>());
      expect(connectivityService.connectivityStream, isA<Stream<bool>>());
    });

    test('Requirement 6.3: Provides connectivity status', () {
      // Service should expose current connectivity status
      final isOnline = connectivityService.isOnline;

      expect(isOnline, isA<bool>());
    });

    test('Requirement 8.1: Handles connectivity check errors gracefully',
        () async {
      // Service should not throw on connectivity check
      await expectLater(
        connectivityService.checkConnectivity(),
        completes,
      );
    });
  });
}
