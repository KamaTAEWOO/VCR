import 'vcr_message.dart';
import '../protocol.dart';

/// Screen frame data sent from Server to Client.
///
/// Contains a Base64-encoded JPEG image of a device screen.
///
/// ```json
/// {
///   "type": "frame",
///   "payload": {
///     "data": "<base64 encoded JPEG>",
///     "width": 1080,
///     "height": 1920,
///     "seq": 42,
///     "deviceId": "LMV500Ne6f3ea0c",
///     "deviceName": "LG V500N",
///     "platform": "android"
///   }
/// }
/// ```
class FrameData {
  /// Base64-encoded JPEG image data
  final String data;

  /// Image width in pixels
  final int width;

  /// Image height in pixels
  final int height;

  /// Frame sequence number for ordering and drop detection
  final int seq;

  /// Device serial number or UDID (null for backward compatibility)
  final String? deviceId;

  /// Human-readable device name (null for backward compatibility)
  final String? deviceName;

  /// Device platform: 'android' (null for backward compatibility)
  final String? platform;

  const FrameData({
    required this.data,
    required this.width,
    required this.height,
    required this.seq,
    this.deviceId,
    this.deviceName,
    this.platform,
  });

  factory FrameData.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return FrameData(
      data: payload['data'] as String? ?? '',
      width: payload['width'] as int? ?? 0,
      height: payload['height'] as int? ?? 0,
      seq: payload['seq'] as int? ?? 0,
      deviceId: payload['deviceId'] as String?,
      deviceName: payload['deviceName'] as String?,
      platform: payload['platform'] as String?,
    );
  }

  factory FrameData.fromMessage(VcrMessage message) {
    return FrameData(
      data: message.payload['data'] as String? ?? '',
      width: message.payload['width'] as int? ?? 0,
      height: message.payload['height'] as int? ?? 0,
      seq: message.payload['seq'] as int? ?? 0,
      deviceId: message.payload['deviceId'] as String?,
      deviceName: message.payload['deviceName'] as String?,
      platform: message.payload['platform'] as String?,
    );
  }

  VcrMessage toMessage() {
    final payloadMap = <String, dynamic>{
      'data': data,
      'width': width,
      'height': height,
      'seq': seq,
    };
    if (deviceId != null) payloadMap['deviceId'] = deviceId;
    if (deviceName != null) payloadMap['deviceName'] = deviceName;
    if (platform != null) payloadMap['platform'] = platform;
    return VcrMessage(
      type: MessageType.frame,
      payload: payloadMap,
    );
  }

  Map<String, dynamic> toJson() => toMessage().toJson();

  @override
  String toString() =>
      'FrameData(width: $width, height: $height, seq: $seq, '
      'deviceId: $deviceId, platform: $platform, data: ${data.length} chars)';
}
