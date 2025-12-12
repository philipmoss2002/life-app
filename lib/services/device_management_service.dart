import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/device.dart';

/// Service for managing connected devices
class DeviceManagementService {
  // Instance-specific storage for testing
  final List<Device> _mockDevices = [];
  String? _currentDeviceId;
  bool _initialized = false;

  /// Get all devices for the current user
  Future<List<Device>> getDevices() async {
    // In production, this would fetch from DynamoDB
    // For now, return mock data with current device
    if (!_initialized) {
      await _initializeMockDevices();
      _initialized = true;
    }
    return List.from(_mockDevices);
  }

  /// Register a new device
  Future<Device> registerDevice(String userId) async {
    final deviceInfo = await _getDeviceInfo();
    final device = Device(
      id: deviceInfo['id']!,
      userId: userId,
      deviceName: deviceInfo['name']!,
      deviceType: deviceInfo['type']!,
      lastSyncTime: DateTime.now(),
      registeredAt: DateTime.now(),
      isActive: true,
    );

    // In production, this would save to DynamoDB
    _mockDevices.add(device);
    _currentDeviceId = device.id;

    return device;
  }

  /// Remove a device from the user's account
  Future<void> removeDevice(String deviceId) async {
    // In production, this would delete from DynamoDB and revoke access
    _mockDevices.removeWhere((device) => device.id == deviceId);
  }

  /// Update device last sync time
  Future<void> updateLastSyncTime(String deviceId) async {
    final index = _mockDevices.indexWhere((device) => device.id == deviceId);
    if (index != -1) {
      _mockDevices[index] = _mockDevices[index].copyWith(
        lastSyncTime: DateTime.now(),
      );
    }
  }

  /// Get current device ID
  String? getCurrentDeviceId() {
    return _currentDeviceId;
  }

  /// Get device information
  Future<Map<String, String>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Unknown Device';
    String deviceType = 'phone';
    String deviceId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.brand} ${androidInfo.model}';
        deviceType = androidInfo.isPhysicalDevice ? 'phone' : 'tablet';
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
        deviceType =
            iosInfo.model.toLowerCase().contains('ipad') ? 'tablet' : 'phone';
        deviceId = iosInfo.identifierForVendor ?? deviceId;
      }
    } catch (e) {
      // Use defaults if device info fails
    }

    return {
      'id': deviceId,
      'name': deviceName,
      'type': deviceType,
    };
  }

  /// Initialize mock devices for testing
  Future<void> _initializeMockDevices() async {
    final currentDevice = await _getDeviceInfo();
    _currentDeviceId = currentDevice['id'];

    // Add current device
    _mockDevices.add(Device(
      id: currentDevice['id']!,
      userId: 'user123',
      deviceName: currentDevice['name']!,
      deviceType: currentDevice['type']!,
      lastSyncTime: DateTime.now(),
      registeredAt: DateTime.now().subtract(const Duration(days: 5)),
      isActive: true,
    ));

    // Add some mock devices for demonstration
    _mockDevices.add(Device(
      id: 'device_2',
      userId: 'user123',
      deviceName: 'Samsung Galaxy S21',
      deviceType: 'phone',
      lastSyncTime: DateTime.now().subtract(const Duration(hours: 2)),
      registeredAt: DateTime.now().subtract(const Duration(days: 30)),
      isActive: true,
    ));

    _mockDevices.add(Device(
      id: 'device_3',
      userId: 'user123',
      deviceName: 'iPad Pro',
      deviceType: 'tablet',
      lastSyncTime: DateTime.now().subtract(const Duration(days: 7)),
      registeredAt: DateTime.now().subtract(const Duration(days: 60)),
      isActive: true,
    ));

    // Add an inactive device (hasn't synced in 90+ days)
    _mockDevices.add(Device(
      id: 'device_4',
      userId: 'user123',
      deviceName: 'Old Phone',
      deviceType: 'phone',
      lastSyncTime: DateTime.now().subtract(const Duration(days: 120)),
      registeredAt: DateTime.now().subtract(const Duration(days: 365)),
      isActive: false,
    ));
  }
}
