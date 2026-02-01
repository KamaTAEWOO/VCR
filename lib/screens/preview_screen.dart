import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/device_info.dart';
import '../providers/preview_provider.dart';

/// Full-screen ViewPager for browsing connected device screen captures.
///
/// Each page shows exactly ONE device's live capture, filling the entire screen.
/// Supports pinch-to-zoom via InteractiveViewer within each page.
/// Swipe left/right to switch between devices (like a photo gallery).
/// Tap anywhere to toggle overlay UI visibility.
///
/// Features:
/// - Page indicator dots at the bottom
/// - Device info overlay at the top (name + platform icon)
/// - FPS counter in the bottom-left corner
/// - Floating back button
/// - Black background for immersive viewing
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late PageController _pageController;

  /// The device ID passed as a route argument (if any).
  String? _initialDeviceId;
  bool _didInit = false;

  /// Whether overlay UI (device info, indicators, back button) is visible.
  bool _showOverlay = true;

  /// Tracks the current page index for the dot indicator.
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _didInit = true;
      // Read route arguments for initial device selection
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is String) {
        _initialDeviceId = args;
      }

      // Set initial page to match the selected device
      final previewProvider = context.read<PreviewProvider>();
      if (_initialDeviceId != null) {
        previewProvider.selectDevice(_initialDeviceId!);
      }

      final devices = previewProvider.devices;
      final selectedId =
          _initialDeviceId ?? previewProvider.selectedDeviceId;
      if (devices.isNotEmpty && selectedId != null) {
        final index = devices.indexWhere((d) => d.id == selectedId);
        if (index >= 0) {
          _currentPage = index;
          _pageController = PageController(initialPage: index);
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<PreviewProvider>(
        builder: (context, previewProvider, _) {
          final devices = previewProvider.devices;

          // No devices or legacy mode: show single preview
          if (devices.isEmpty) {
            return _buildLegacySinglePage(previewProvider);
          }

          return _buildViewPager(previewProvider, devices);
        },
      ),
    );
  }

  // ===========================================================================
  // Legacy single preview (no device info, just a frame)
  // ===========================================================================

  Widget _buildLegacySinglePage(PreviewProvider previewProvider) {
    return GestureDetector(
      onTap: _toggleOverlay,
      child: Stack(
        children: [
          // Fullscreen frame
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: _DeviceFrameView(
                frameBytes: previewProvider.currentFrame,
              ),
            ),
          ),

          // Overlay UI
          if (_showOverlay) ...[
            _buildFpsOverlay(previewProvider),
            _buildBackButton(),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Main ViewPager: fullscreen PageView for all devices
  // ===========================================================================

  Widget _buildViewPager(
    PreviewProvider previewProvider,
    List<DeviceInfo> devices,
  ) {
    return GestureDetector(
      onTap: _toggleOverlay,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // The fullscreen PageView
          PageView.builder(
            controller: _pageController,
            itemCount: devices.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              previewProvider.selectDevice(devices[index].id);
            },
            itemBuilder: (context, index) {
              final device = devices[index];
              return _FullscreenDevicePage(
                frameBytes: previewProvider.getFrameForDevice(device.id),
              );
            },
          ),

          // Top: device info overlay
          if (_showOverlay)
            _buildDeviceInfoOverlay(
              devices,
              _currentPage.clamp(0, devices.length - 1),
            ),

          // Bottom: page indicator dots + FPS + back button
          if (_showOverlay) ...[
            _buildBottomBar(previewProvider, devices),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Device info overlay (top)
  // ===========================================================================

  Widget _buildDeviceInfoOverlay(List<DeviceInfo> devices, int index) {
    final device = devices[index];

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: AnimatedOpacity(
        opacity: _showOverlay ? 1.0 : 0.0,
        duration: VcrDurations.fadeIn,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black87,
                Colors.black54,
                Colors.transparent,
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Row(
                children: [
                  // Platform icon
                  Container(
                    padding: const EdgeInsets.all(Spacing.xs),
                    decoration: BoxDecoration(
                      color: VcrColors.bgTertiary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Icon(
                      Icons.phone_android,
                      size: 18,
                      color: VcrColors.accent,
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  // Device name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          device.name,
                          style: VcrTypography.bodyMedium.copyWith(
                            color: VcrColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (devices.length > 1)
                          Text(
                            '${index + 1} / ${devices.length}',
                            style: VcrTypography.labelMedium.copyWith(
                              color: VcrColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Capturing indicator
                  if (device.isCapturing)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.sm,
                        vertical: Spacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: VcrColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(Radii.full),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: VcrColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            'LIVE',
                            style: VcrTypography.labelMedium.copyWith(
                              color: VcrColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom bar: page dots + FPS + back button
  // ===========================================================================

  Widget _buildBottomBar(
    PreviewProvider previewProvider,
    List<DeviceInfo> devices,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        opacity: _showOverlay ? 1.0 : 0.0,
        duration: VcrDurations.fadeIn,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black87,
                Colors.black54,
                Colors.transparent,
              ],
              stops: [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicator dots (only for multiple devices)
                  if (devices.length > 1) ...[
                    _PageIndicatorDots(
                      count: devices.length,
                      currentIndex: _currentPage.clamp(
                        0,
                        devices.length - 1,
                      ),
                      onDotTapped: (index) {
                        _pageController.animateToPage(
                          index,
                          duration: VcrDurations.fadeIn,
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                    const SizedBox(height: Spacing.sm),
                  ],

                  // FPS + back button row
                  Row(
                    children: [
                      // FPS counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: Spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: VcrColors.bgTertiary.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: Text(
                          '${previewProvider.fps} fps',
                          style: VcrTypography.labelMedium.copyWith(
                            color: VcrColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Back button
                      _buildBackButtonWidget(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // FPS overlay (for legacy single preview)
  // ===========================================================================

  Widget _buildFpsOverlay(PreviewProvider previewProvider) {
    return Positioned(
      left: Spacing.md,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: VcrColors.bgTertiary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: Text(
            '${previewProvider.fps} fps',
            style: VcrTypography.labelMedium.copyWith(
              color: VcrColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Back button
  // ===========================================================================

  Widget _buildBackButton() {
    return Positioned(
      right: Spacing.md,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: _buildBackButtonWidget(),
      ),
    );
  }

  Widget _buildBackButtonWidget() {
    return Material(
      color: VcrColors.bgTertiary.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(Radii.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.full),
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(Spacing.sm),
          child: Icon(
            Icons.close,
            color: VcrColors.textPrimary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Fullscreen Device Page (one device per page)
// =============================================================================

/// A single page within the ViewPager showing one device's screen capture.
/// Uses InteractiveViewer for pinch-to-zoom support.
class _FullscreenDevicePage extends StatelessWidget {
  final Uint8List? frameBytes;

  const _FullscreenDevicePage({
    required this.frameBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: _DeviceFrameView(frameBytes: frameBytes),
      ),
    );
  }
}

// =============================================================================
// Device Frame View (renders the actual screen capture image)
// =============================================================================

/// Renders a device's screen capture image, or a placeholder if no frame.
class _DeviceFrameView extends StatelessWidget {
  final Uint8List? frameBytes;

  const _DeviceFrameView({required this.frameBytes});

  @override
  Widget build(BuildContext context) {
    if (frameBytes == null) {
      return _buildPlaceholder();
    }

    return Image.memory(
      frameBytes!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.phone_android,
            size: 64,
            color: VcrColors.textMuted,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Waiting for screen capture...',
            style: VcrTypography.bodyMedium.copyWith(
              color: VcrColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Page Indicator Dots
// =============================================================================

/// Standard page indicator dots (like a ViewPager indicator).
class _PageIndicatorDots extends StatelessWidget {
  final int count;
  final int currentIndex;
  final ValueChanged<int>? onDotTapped;

  const _PageIndicatorDots({
    required this.count,
    required this.currentIndex,
    this.onDotTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return GestureDetector(
          onTap: onDotTapped != null ? () => onDotTapped!(index) : null,
          child: AnimatedContainer(
            duration: VcrDurations.fadeIn,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive
                  ? VcrColors.accent
                  : VcrColors.textMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
        );
      }),
    );
  }
}
