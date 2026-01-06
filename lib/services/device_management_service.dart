import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:amplify_core/amplify_core.dart' as amplify_core;
import '../models/Device.dart';
import 'authentication_service.dart';

/// Service for managing connected devices
class DeviceManagementService {
  // Instance-specific storage for testing
  final List<Device> _mockDevices = [];
  String? _currentDeviceId;
  bool _initialized = false;
  final AuthenticationService _authService = AuthenticationService();

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
      userId: userId, // Add userId parameter
      deviceName: deviceInfo['name']!,
      deviceType: deviceInfo['type']!,
      lastSyncTime: amplify_core.TemporalDateTime.now(),
      isActive: true,
      createdAt: amplify_core.TemporalDateTime.now(),
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
        lastSyncTime: amplify_core.TemporalDateTime.now(),
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

    // Get current user for userId
    final currentUser = await _authService.getCurrentUser();
    final userId = currentUser?.id ?? 'anonymous';

    final now = amplify_core.TemporalDateTime.now();

    // Add current device
    _mockDevices.add(Device(
      userId: userId,
      deviceName: currentDevice['name']!,
      deviceType: currentDevice['type']!,
      lastSyncTime: now,
      isActive: true,
      createdAt: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(days: 5)).toIso8601String()),
    ));

    // Add some mock devices for demonstration
    _mockDevices.add(Device(
      userId: userId,
      deviceName: 'Samsung Galaxy S21',
      deviceType: 'phone',
      lastSyncTime: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(hours: 2)).toIso8601String()),
      isActive: true,
      createdAt: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String()),
    ));

    _mockDevices.add(Device(
      userId: userId,
      deviceName: 'iPad Pro',
      deviceType: 'tablet',
      lastSyncTime: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(days: 7)).toIso8601String()),
      isActive: true,
      createdAt: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(days: 60)).toIso8601String()),
    ));

    // Add an inactive device (hasn't synced in 90+ days)
    _mockDevices.add(Device(
      userId: userId,
      deviceName: 'Old Phone',
      deviceType: 'phone',
      lastSyncTime: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(days: 120)).toIso8601String()),
      isActive: false,
      createdAt: amplify_core.TemporalDateTime.fromString(
          DateTime.now().subtract(const Duration(days: 365)).toIso8601String()),
    ));
  }

  /// Check if device is inactive (hasn't synced in 90+ days)
  bool isDeviceInactive(Device device) {
    final lastSync = device.lastSyncTime.getDateTimeInUtc();
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    return lastSync.isBefore(cutoff);
  }

  /// Get device registration date (using createdAt)
  amplify_core.TemporalDateTime getDeviceRegistrationDate(Device device) {
    return device.createdAt;
  }
}
