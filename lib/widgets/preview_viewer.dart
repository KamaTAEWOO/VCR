import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Displays the current emulator screen frame as an Image.
///
/// Shows a placeholder when no frame is available.
/// Uses gaplessPlayback: true to prevent flicker between frames.
/// Optionally shows device name and platform icon overlay.
/// Matches UI_SPEC.md section 4.4.
class PreviewViewer extends StatelessWidget {
  final Uint8List? frameBytes;
  final bool mini;

  /// Optional device name to show as an overlay label.
  final String? deviceName;

  /// Optional platform ('android') for the platform icon overlay.
  final String? platform;

  /// Whether to show the device info overlay (name + platform icon).
  final bool showDeviceLabel;

  const PreviewViewer({
    super.key,
    this.frameBytes,
    this.mini = false,
    this.deviceName,
    this.platform,
    this.showDeviceLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    if (frameBytes == null) {
      return _buildPlaceholder();
    }

    final image = Image.memory(
      frameBytes!,
      fit: mini ? BoxFit.cover : BoxFit.contain,
      gaplessPlayback: true,
    );

    if (!showDeviceLabel || deviceName == null) {
      return image;
    }

    // Wrap with device info overlay
    return Stack(
      children: [
        Positioned.fill(child: image),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _DeviceLabelOverlay(
            deviceName: deviceName!,
            platform: platform,
            mini: mini,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.phone_android,
            size: 48,
            color: VcrColors.textMuted,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'No preview',
            style: VcrTypography.bodyMedium.copyWith(
              color: VcrColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Overlay showing device name and platform icon at the bottom of the preview.
class _DeviceLabelOverlay extends StatelessWidget {
  final String deviceName;
  final String? platform;
  final bool mini;

  const _DeviceLabelOverlay({
    required this.deviceName,
    this.platform,
    this.mini = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = mini ? 12.0 : 16.0;
    final fontSize = mini ? 10.0 : 12.0;
    final padding = mini
        ? const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2)
        : const EdgeInsets.symmetric(
            horizontal: Spacing.sm, vertical: Spacing.xs);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black87,
          ],
        ),
      ),
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _platformIcon,
            size: iconSize,
            color: VcrColors.textSecondary,
          ),
          SizedBox(width: mini ? 2 : Spacing.xs),
          Flexible(
            child: Text(
              deviceName,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: VcrColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  IconData get _platformIcon {
    return Icons.phone_android;
  }
}
