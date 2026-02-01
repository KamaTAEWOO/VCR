import 'vcr_message.dart';
import '../protocol.dart';

/// Information about a connected Android device.
///
/// ```json
/// {
///   "id": "LMV500Ne6f3ea0c",
///   "name": "LG V500N",
///   "platform": "android",
///   "isCapturing": true
/// }
/// ```
class DeviceInfo {
  /// Device serial number
  final String id;

  /// Human-readable device name (e.g. "LG V500N", "Galaxy S24")
  final String name;

  /// Device platform: 'android'
  final String platform;

  /// Whether screen capture is currently active for this device
  final bool isCapturing;

  const DeviceInfo({
    required this.id,
    required this.name,
    required this.platform,
    this.isCapturing = false,
  });

  /// Create a copy with updated fields.
  DeviceInfo copyWith({
    String? id,
    String? name,
    String? platform,
    bool? isCapturing,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      isCapturing: isCapturing ?? this.isCapturing,
    );
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      platform: json['platform'] as String? ?? 'android',
      isCapturing: json['isCapturing'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'platform': platform,
        'isCapturing': isCapturing,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DeviceInfo(id: $id, name: $name, platform: $platform, '
      'isCapturing: $isCapturing)';
}

/// Device list message sent from Server to Client.
///
/// ```json
/// {
///   "type": "devices",
///   "payload": {
///     "devices": [
///       {"id": "LMV500Ne6f3ea0c", "name": "LG V500N", "platform": "android", "isCapturing": true}
///     ]
///   }
/// }
/// ```
class DeviceListData {
  /// List of connected devices
  final List<DeviceInfo> devices;

  const DeviceListData({required this.devices});

  factory DeviceListData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    final deviceList = (payload['devices'] as List<dynamic>?)
            ?.map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DeviceListData(devices: deviceList);
  }

  factory DeviceListData.fromMessage(VcrMessage message) {
    final deviceList = (message.payload['devices'] as List<dynamic>?)
            ?.map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DeviceListData(devices: deviceList);
  }

  VcrMessage toMessage() {
    return VcrMessage(
      type: MessageType.devices,
      payload: {
        'devices': devices.map((d) => d.toJson()).toList(),
      },
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  @override
  String toString() => 'DeviceListData(devices: $devices)';
}
