import 'package:flutter/foundation.dart';
import '../models/agent_state.dart';
import '../models/device_info.dart';

/// The default device ID used when frames arrive without a deviceId.
const String kDefaultDeviceId = 'default';

/// Manages emulator preview frame data, agent state, and FPS counter.
///
/// Supports multiple connected devices. Each device has its own frame buffer.
/// A selected device ID controls which device is shown in fullscreen preview.
class PreviewProvider extends ChangeNotifier {
  // -- Multi-device state --

  /// Frames keyed by device ID.
  final Map<String, Uint8List> _deviceFrames = {};

  /// Connected devices keyed by device ID.
  final Map<String, DeviceInfo> _devices = {};

  /// Currently selected device for fullscreen preview.
  String? _selectedDeviceId;

  // -- Legacy single-frame compat --

  AgentState _agentState = AgentState.idle;
  int _fps = 0;
  bool _showMiniPreview = false;

  // FPS calculation helpers (global across all devices)
  int _frameCount = 0;
  DateTime _lastFpsUpdate = DateTime.now();

  /// Last received frame sequence number per device (skip duplicate notifies).
  final Map<String, int> _lastFrameSeq = {};

  // =========================================================================
  // Getters
  // =========================================================================

  /// The currently selected device frame (for fullscreen preview).
  /// Falls back to the first available frame if no device is selected.
  Uint8List? get currentFrame => selectedFrame;

  /// Frame for the currently selected device, or the first available frame.
  Uint8List? get selectedFrame {
    // Try selected device first
    if (_selectedDeviceId != null &&
        _deviceFrames.containsKey(_selectedDeviceId)) {
      return _deviceFrames[_selectedDeviceId];
    }
    // Fall back to first available
    if (_deviceFrames.isNotEmpty) {
      return _deviceFrames.values.first;
    }
    return null;
  }

  /// Get the frame for a specific device.
  Uint8List? getFrameForDevice(String deviceId) => _deviceFrames[deviceId];

  /// List of all known connected devices.
  List<DeviceInfo> get devices => _devices.values.toList();

  /// The currently selected device ID.
  String? get selectedDeviceId => _selectedDeviceId;

  /// Info for the currently selected device.
  DeviceInfo? get selectedDevice {
    if (_selectedDeviceId != null) {
      return _devices[_selectedDeviceId];
    }
    if (_devices.isNotEmpty) {
      return _devices.values.first;
    }
    return null;
  }

  AgentState get agentState => _agentState;
  int get fps => _fps;
  bool get showMiniPreview => _showMiniPreview;

  /// Whether we have any device frames to show.
  bool get hasFrames => _deviceFrames.isNotEmpty;

  /// Number of connected devices.
  int get deviceCount => _devices.length;

  // =========================================================================
  // Device management
  // =========================================================================

  /// Update the full device list (from a 'devices' message).
  ///
  /// Removes frames for devices that are no longer in the list.
  void updateDeviceList(List<DeviceInfo> deviceList) {
    final newIds = deviceList.map((d) => d.id).toSet();

    // Remove frames for devices no longer in the list
    _deviceFrames.removeWhere((id, _) => !newIds.contains(id));
    _lastFrameSeq.removeWhere((id, _) => !newIds.contains(id));

    // Update device map
    _devices.clear();
    for (final device in deviceList) {
      _devices[device.id] = device;
    }

    // If selected device was removed, reset selection
    if (_selectedDeviceId != null && !newIds.contains(_selectedDeviceId)) {
      _selectedDeviceId = deviceList.isNotEmpty ? deviceList.first.id : null;
    }

    notifyListeners();
  }

  /// Select a device for fullscreen preview.
  void selectDevice(String deviceId) {
    if (_selectedDeviceId != deviceId) {
      _selectedDeviceId = deviceId;
      notifyListeners();
    }
  }

  // =========================================================================
  // Frame updates
  // =========================================================================

  /// Update the frame for a specific device.
  ///
  /// If [deviceId] is null, uses the default device ID for backward
  /// compatibility with agents that don't send device info.
  /// If [deviceName] and [platform] are provided and the device isn't tracked
  /// yet, a DeviceInfo is auto-created.
  void updateFrame(
    Uint8List frameBytes, {
    int seq = -1,
    String? deviceId,
    String? deviceName,
    String? platform,
  }) {
    final effectiveDeviceId = deviceId ?? kDefaultDeviceId;

    // Auto-register device if not already tracked
    if (!_devices.containsKey(effectiveDeviceId)) {
      _devices[effectiveDeviceId] = DeviceInfo(
        id: effectiveDeviceId,
        name: deviceName ?? 'Device',
        platform: platform ?? 'android',
        isCapturing: true,
      );
    }

    _deviceFrames[effectiveDeviceId] = frameBytes;
    _frameCount++;

    // Auto-select first device if nothing is selected
    _selectedDeviceId ??= effectiveDeviceId;

    // Recalculate FPS every second (global across all devices)
    final now = DateTime.now();
    final elapsed = now.difference(_lastFpsUpdate).inMilliseconds;
    bool fpsChanged = false;
    if (elapsed >= 1000) {
      final newFps = (_frameCount * 1000 / elapsed).round();
      fpsChanged = newFps != _fps;
      _fps = newFps;
      _frameCount = 0;
      _lastFpsUpdate = now;
    }

    // Skip notifyListeners if this is a duplicate frame seq for this device
    final lastSeq = _lastFrameSeq[effectiveDeviceId] ?? -1;
    if (seq >= 0 && seq == lastSeq && !fpsChanged) {
      return;
    }
    _lastFrameSeq[effectiveDeviceId] = seq;

    notifyListeners();
  }

  // =========================================================================
  // Agent state
  // =========================================================================

  /// Update the agent state (from status messages).
  void setAgentState(AgentState state) {
    if (_agentState != state) {
      _agentState = state;
      notifyListeners();
    }
  }

  // =========================================================================
  // Mini preview
  // =========================================================================

  /// Toggle the mini preview panel in terminal screen.
  void toggleMiniPreview() {
    _showMiniPreview = !_showMiniPreview;
    notifyListeners();
  }

  /// Set mini preview visibility directly.
  void setMiniPreview(bool show) {
    if (_showMiniPreview != show) {
      _showMiniPreview = show;
      notifyListeners();
    }
  }

  // =========================================================================
  // Cleanup
  // =========================================================================

  /// Clear all frames (e.g. on disconnect).
  void clearFrame() {
    _deviceFrames.clear();
    _fps = 0;
    _frameCount = 0;
    notifyListeners();
  }

  /// Reset everything (on disconnect).
  void reset() {
    _deviceFrames.clear();
    _devices.clear();
    _selectedDeviceId = null;
    _lastFrameSeq.clear();
    _agentState = AgentState.disconnected;
    _fps = 0;
    _frameCount = 0;
    notifyListeners();
  }
}
