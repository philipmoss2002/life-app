/// Device model representing a connected device
class Device {
  final String id;
  final String userId;
  final String deviceName;
  final String deviceType; // 'phone', 'tablet'
  final DateTime lastSyncTime;
  final DateTime registeredAt;
  final bool isActive;

  Device({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.deviceType,
    required this.lastSyncTime,
    required this.registeredAt,
    required this.isActive,
  });

  /// Create Device from map
  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'] as String,
      userId: map['userId'] as String,
      deviceName: map['deviceName'] as String,
      deviceType: map['deviceType'] as String,
      lastSyncTime: DateTime.parse(map['lastSyncTime'] as String),
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      isActive: map['isActive'] as bool,
    );
  }

  /// Convert Device to map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'lastSyncTime': lastSyncTime.toIso8601String(),
      'registeredAt': registeredAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Check if device is inactive (hasn't synced in 90 days)
  bool get isInactive {
    final daysSinceLastSync = DateTime.now().difference(lastSyncTime).inDays;
    return daysSinceLastSync >= 90;
  }

  /// Copy with method for updating fields
  Device copyWith({
    String? id,
    String? userId,
    String? deviceName,
    String? deviceType,
    DateTime? lastSyncTime,
    DateTime? registeredAt,
    bool? isActive,
  }) {
    return Device(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceName: deviceName ?? this.deviceName,
      deviceType: deviceType ?? this.deviceType,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      registeredAt: registeredAt ?? this.registeredAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
