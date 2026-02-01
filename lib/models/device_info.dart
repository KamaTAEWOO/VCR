/// Device information for a connected emulator/device.
///
/// This is a local App model. When the shared package adds DeviceInfo,
/// this can be replaced or adapted to wrap the shared version.
class DeviceInfo {
  final String id;
  final String name;
  final String platform; // 'android'
  final bool isCapturing;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    this.isCapturing = false,
  });

  /// Create from a JSON map (from the 'devices' message payload).
  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String? ?? 'unknown',
      name: json['name'] as String? ?? 'Unknown Device',
      platform: json['platform'] as String? ?? 'android',
      isCapturing: json['is_capturing'] as bool? ?? false,
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'is_capturing': isCapturing,
    };
  }

  /// A default device used for backward compatibility when no deviceId
  /// is provided in frame messages.
  static const DeviceInfo defaultDevice = DeviceInfo(
    id: 'default',
    name: 'Device',
    platform: 'android',
    isCapturing: true,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          platform == other.platform &&
          isCapturing == other.isCapturing;

  @override
  int get hashCode => Object.hash(id, name, platform, isCapturing);

  @override
  String toString() =>
      'DeviceInfo(id: $id, name: $name, platform: $platform, isCapturing: $isCapturing)';
}
