import 'dart:typed_data';

// TODO: Replace with package:vcr_shared FrameData. This app-local version
// stores decoded Uint8List bytes while shared stores Base64 String data.
// Consider renaming to DecodedFrame and wrapping the shared FrameData.

/// Decoded frame data from VCR Agent (type: "frame").
///
/// When shared package is ready, replace this with shared's definition.
class FrameData {
  final Uint8List bytes;
  final int width;
  final int height;
  final int seq;

  /// Device identification fields (nullable for backward compatibility with
  /// agents that don't send device info in frame messages).
  final String? deviceId;
  final String? deviceName;
  final String? platform;

  const FrameData({
    required this.bytes,
    required this.width,
    required this.height,
    required this.seq,
    this.deviceId,
    this.deviceName,
    this.platform,
  });

  /// Parse device identification fields from a frame payload map.
  ///
  /// Returns a record of (deviceId, deviceName, platform) extracted from
  /// the payload. All fields are nullable for backward compatibility.
  static ({String? deviceId, String? deviceName, String? platform})
      parseDeviceFields(Map<String, dynamic> payload) {
    return (
      deviceId: payload['device_id'] as String?,
      deviceName: payload['device_name'] as String?,
      platform: payload['platform'] as String?,
    );
  }
}
