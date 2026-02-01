import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:vcr_shared/vcr_shared.dart';

import 'device_controller.dart';

/// Callback type for frame data
typedef FrameCallback = void Function(FrameData frame);

/// Captures a single Android device's screen and converts to JPEG Base64.
///
/// Each instance handles ONE device. For multiple devices, create
/// multiple ScreenCapture instances.
///
/// Uses `adb -s <deviceId> exec-out screencap -p` for screen capture.
///
/// Runs on a periodic timer (~10fps = 100ms interval).
class ScreenCapture {
  final DeviceInfo device;
  final DeviceController _deviceController;

  /// Timer for periodic capture
  Timer? _captureTimer;

  /// Whether capture is currently active
  bool _isCapturing = false;

  /// Frame sequence counter
  int _frameSeq = 0;

  /// Callback for new frames
  FrameCallback? onFrame;

  /// Callback invoked when capture is paused due to consecutive failures.
  /// Receives the reason string for the last failure.
  void Function(String reason)? onPause;

  /// Capture interval in milliseconds
  int captureIntervalMs;

  /// JPEG quality (0-100)
  int jpegQuality;

  /// Number of consecutive capture failures
  int _failureCount = 0;

  /// Maximum consecutive failures before pausing capture
  static const int _maxConsecutiveFailures = 3;

  /// Whether a capture is currently in progress (prevents overlapping)
  bool _captureInProgress = false;

  /// Whether capture is currently running
  bool get isCapturing => _isCapturing;

  /// Current frame sequence number
  int get frameSeq => _frameSeq;

  ScreenCapture({
    required this.device,
    DeviceController? deviceController,
    this.captureIntervalMs = ConnectionDefaults.captureIntervalMs,
    this.jpegQuality = ConnectionDefaults.jpegQuality,
  }) : _deviceController = deviceController ?? DeviceController();

  /// Start periodic screen capture for this device.
  ///
  /// Verifies ADB is available for Android devices.
  /// Captures frames at the configured interval and delivers them
  /// via the [onFrame] callback.
  Future<void> start() async {
    if (_isCapturing) return;

    final adbPath = await _deviceController.getAdbPath();
    if (adbPath == null) {
      throw ScreenCaptureException(
        'ADB not found. Please install Android SDK.',
        ErrorCode.adbNotFound,
      );
    }

    _isCapturing = true;
    _failureCount = 0;
    _frameSeq = 0;

    // Start periodic capture timer
    _captureTimer =
        Timer.periodic(Duration(milliseconds: captureIntervalMs), (_) {
      _captureFrame();
    });
  }

  /// Stop screen capture.
  void stop() {
    _captureTimer?.cancel();
    _captureTimer = null;
    _isCapturing = false;
  }

  /// Capture a single frame from the Android device.
  Future<void> _captureFrame() async {
    if (!_isCapturing || _captureInProgress) return;
    _captureInProgress = true;

    try {
      final pngBytes = await _captureAndroid();

      if (pngBytes == null || pngBytes.isEmpty) {
        _handleFailure('Empty screenshot data from ${device.name}');
        return;
      }

      // Decode PNG
      final image = img.decodePng(pngBytes);
      if (image == null) {
        _handleFailure('Failed to decode PNG from ${device.name}');
        return;
      }

      // Encode to JPEG with specified quality
      final jpegBytes = img.encodeJpg(image, quality: jpegQuality);

      // Base64 encode
      final base64Data = base64Encode(jpegBytes);

      // Create frame data with device identification
      final frame = FrameData(
        data: base64Data,
        width: image.width,
        height: image.height,
        seq: _frameSeq++,
        deviceId: device.id,
        deviceName: device.name,
        platform: device.platform,
      );

      // Reset failure count on success
      _failureCount = 0;

      // Deliver frame via callback
      onFrame?.call(frame);
    } catch (e) {
      _handleFailure('Capture error (${device.name}): $e');
    } finally {
      _captureInProgress = false;
    }
  }

  /// Capture screenshot from an Android device.
  Future<Uint8List?> _captureAndroid() async {
    final adbPath = await _deviceController.getAdbPath();
    if (adbPath == null) return null;

    final result = await Process.run(
      adbPath,
      ['-s', device.id, 'exec-out', 'screencap', '-p'],
      stdoutEncoding: null, // Get raw bytes
    );

    if (result.exitCode != 0) {
      _handleFailure('screencap failed for ${device.id}: ${result.stderr}');
      return null;
    }

    final bytes = result.stdout as List<int>;
    if (bytes.isEmpty) return null;

    return Uint8List.fromList(bytes);
  }

  /// Handle a capture failure, pausing after too many consecutive failures.
  void _handleFailure(String reason) {
    _failureCount++;
    if (_failureCount >= _maxConsecutiveFailures) {
      stop();
      // Notify listener that capture has been paused due to failures
      onPause?.call(
          'Screen capture paused for ${device.name} after '
          '$_maxConsecutiveFailures consecutive failures. Last error: $reason');
    }
  }

  /// Dispose all resources.
  void dispose() {
    stop();
  }
}

/// Exception thrown by [ScreenCapture] operations.
class ScreenCaptureException implements Exception {
  final String message;
  final String errorCode;

  const ScreenCaptureException(this.message, this.errorCode);

  @override
  String toString() => 'ScreenCaptureException($errorCode): $message';
}
