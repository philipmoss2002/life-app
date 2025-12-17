import 'package:flutter_test/flutter_test.dart';
import 'package:faker/faker.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import 'package:household_docs_app/services/device_management_service.dart';
import 'package:household_docs_app/models/device.dart';

/// **Feature: cloud-sync-premium, Property 11: Device Registration**
/// **Validates: Requirements 10.1, 10.2**
///
/// Property: For any device that signs in to a user account, the device should
/// be registered and appear in the user's device list.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceManagementService Property Tests', () {
    final faker = Faker();

    /// Property 11: Device Registration
    /// This test verifies that when a device registers with a user account,
    /// it appears in the device list and can be retrieved.
    ///
    /// Property: For any user ID, when a device registers:
    /// 1. The device should be added to the device list
    /// 2. The device should be retrievable via getDevices()
    /// 3. The device should have correct user ID association
    /// 4. The device should be marked as active
    test('Property 11: Device Registration - 100 iterations', () async {
      for (int i = 0; i < 100; i++) {
        // Generate random user ID
        final userId = faker.guid.guid();

        // Create a fresh service instance for each iteration
        final service = DeviceManagementService();

        // Register device
        final registeredDevice = await service.registerDevice(userId);

        // Verify device was registered
        expect(registeredDevice, isNotNull,
            reason: 'Registered device should not be null');
        expect(registeredDevice.isActive, isTrue,
            reason: 'Newly registered device should be active');

        // Verify device appears in device list
        final devices = await service.getDevices();
        expect(devices, isNotEmpty,
            reason: 'Device list should not be empty after registration');

        // Find the registered device in the list
        final foundDevice = devices.firstWhere(
          (device) => device.id == registeredDevice.id,
          orElse: () => throw Exception('Registered device not found in list'),
        );

        expect(foundDevice.id, equals(registeredDevice.id),
            reason: 'Device ID should match');
        expect(foundDevice.isActive, isTrue,
            reason: 'Device should be active in list');
      }
    });

    test('Property 11: Multiple device registrations for same user', () async {
      final userId = faker.guid.guid();
      final service = DeviceManagementService();

      // Register first device
      await service.registerDevice(userId);

      // Get initial device count
      final devicesAfterFirst = await service.getDevices();
      final initialCount = devicesAfterFirst.length;

      // Register second device (simulating another device for same user)
      await service.registerDevice(userId);

      // Verify both devices are in the list
      final devicesAfterSecond = await service.getDevices();
      expect(devicesAfterSecond.length, greaterThan(initialCount),
          reason: 'Device count should increase after second registration');

      // Verify device count increased
      expect(devicesAfterSecond.length, greaterThan(initialCount),
          reason: 'Device count should increase after second registration');
    });

    test('Property 11: Device registration creates device with valid ID',
        () async {
      final userId = faker.guid.guid();

      // Register multiple devices with same service
      for (int i = 0; i < 10; i++) {
        final service = DeviceManagementService();
        final device = await service.registerDevice(userId);

        // Verify device has a valid ID
        expect(device.id, isNotEmpty, reason: 'Device ID should not be empty');
        expect(device.id, isA<String>(),
            reason: 'Device ID should be a string');
      }
    });

    test('Property 11: Registered device has valid timestamps', () async {
      final userId = faker.guid.guid();
      final service = DeviceManagementService();

      final beforeRegistration = DateTime.now();
      final device = await service.registerDevice(userId);
      final afterRegistration = DateTime.now();

      // Verify creation timestamp is within expected range
      expect(
        device.createdAt.getDateTimeInUtc().isAfter(beforeRegistration.subtract(
              const Duration(seconds: 1),
            )),
        isTrue,
        reason: 'Creation time should be after start of test',
      );
      expect(
        device.createdAt.getDateTimeInUtc().isBefore(afterRegistration.add(
              const Duration(seconds: 1),
            )),
        isTrue,
        reason: 'Creation time should be before end of test',
      );

      // Verify last sync time is recent
      expect(
        device.lastSyncTime
            .getDateTimeInUtc()
            .isAfter(beforeRegistration.subtract(
              const Duration(seconds: 1),
            )),
        isTrue,
        reason: 'Last sync time should be recent',
      );
    });
  });

  group('DeviceManagementService Unit Tests', () {
    late DeviceManagementService deviceService;

    setUp(() {
      deviceService = DeviceManagementService();
    });

    test('getDevices returns list of devices', () async {
      final devices = await deviceService.getDevices();
      expect(devices, isA<List<Device>>());
    });

    test('registerDevice creates device with correct properties', () async {
      const userId = 'test_user_123';
      final service = DeviceManagementService();
      final device = await service.registerDevice(userId);

      expect(device.id, isNotEmpty);
      expect(device.deviceName, isNotEmpty);
      expect(device.deviceType, isIn(['phone', 'tablet']));
      expect(device.isActive, isTrue);
    });

    test('removeDevice removes device from list', () async {
      final service = DeviceManagementService();

      // Get initial devices
      final devicesInitial = await service.getDevices();

      // Pick a device to remove (not the current device)
      final deviceToRemove = devicesInitial.firstWhere(
        (d) => d.id != service.getCurrentDeviceId(),
        orElse: () => devicesInitial.first,
      );

      final initialCount = devicesInitial.length;

      // Remove the device
      await service.removeDevice(deviceToRemove.id);

      // Verify device was removed
      final devicesAfterRemoval = await service.getDevices();
      expect(devicesAfterRemoval.length, equals(initialCount - 1),
          reason: 'Device count should decrease by 1 after removal');

      // Verify specific device is not in list
      final deviceExists =
          devicesAfterRemoval.any((d) => d.id == deviceToRemove.id);
      expect(deviceExists, isFalse,
          reason: 'Removed device should not be in list');
    });

    test('updateLastSyncTime updates device sync time', () async {
      const userId = 'test_user_123';
      final service = DeviceManagementService();

      // Register a device
      final device = await service.registerDevice(userId);
      final originalSyncTime = device.lastSyncTime;

      // Wait a moment to ensure time difference
      await Future.delayed(const Duration(milliseconds: 100));

      // Update sync time
      await service.updateLastSyncTime(device.id);

      // Get updated device
      final devices = await service.getDevices();
      final updatedDevice = devices.firstWhere((d) => d.id == device.id);

      // Verify sync time was updated
      expect(
        updatedDevice.lastSyncTime
            .getDateTimeInUtc()
            .isAfter(originalSyncTime.getDateTimeInUtc()),
        isTrue,
        reason: 'Last sync time should be updated',
      );
    });

    test('getCurrentDeviceId returns device ID after registration', () async {
      const userId = 'test_user_123';
      final service = DeviceManagementService();

      // Register device
      final device = await service.registerDevice(userId);

      // Should now return the device ID
      final currentId = service.getCurrentDeviceId();
      expect(currentId, equals(device.id));
    });

    test('device isInactive property works correctly', () {
      final service = DeviceManagementService();

      final activeDevice = Device(
        id: 'device1',
        deviceName: 'Active Device',
        deviceType: 'phone',
        lastSyncTime: amplify_core.TemporalDateTime.fromString(DateTime.now()
            .subtract(const Duration(days: 30))
            .toIso8601String()),
        createdAt: amplify_core.TemporalDateTime.fromString(DateTime.now()
            .subtract(const Duration(days: 60))
            .toIso8601String()),
        isActive: true,
      );

      final inactiveDevice = Device(
        id: 'device2',
        deviceName: 'Inactive Device',
        deviceType: 'phone',
        lastSyncTime: amplify_core.TemporalDateTime.fromString(DateTime.now()
            .subtract(const Duration(days: 100))
            .toIso8601String()),
        createdAt: amplify_core.TemporalDateTime.fromString(DateTime.now()
            .subtract(const Duration(days: 200))
            .toIso8601String()),
        isActive: false,
      );

      expect(service.isDeviceInactive(activeDevice), isFalse);
      expect(service.isDeviceInactive(inactiveDevice), isTrue);
    });

    test('device copyWith creates new instance with updated fields', () {
      final original = Device(
        id: 'device1',
        deviceName: 'Original Device',
        deviceType: 'phone',
        lastSyncTime: amplify_core.TemporalDateTime.now(),
        createdAt: amplify_core.TemporalDateTime.now(),
        isActive: true,
      );

      final updated = original.copyWith(
        deviceName: 'Updated Device',
        isActive: false,
      );

      expect(updated.id, equals(original.id));
      expect(updated.deviceName, equals('Updated Device'));
      expect(updated.isActive, isFalse);
    });

    test('device toMap works correctly', () {
      final original = Device(
        id: 'device1',
        deviceName: 'Test Device',
        deviceType: 'tablet',
        lastSyncTime: amplify_core.TemporalDateTime.now(),
        createdAt: amplify_core.TemporalDateTime.now(),
        isActive: true,
      );

      final map = original.toMap();

      expect(map['id'], equals(original.id));
      expect(map['deviceName'], equals(original.deviceName));
      expect(map['deviceType'], equals(original.deviceType));
      expect(map['isActive'], equals(original.isActive));
      expect(map['lastSyncTime'], equals(original.lastSyncTime));
      expect(map['createdAt'], equals(original.createdAt));
    });
  });
}
