import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/device_info.dart';
import '../providers/connection_provider.dart';
import '../providers/preview_provider.dart';
import '../providers/terminal_provider.dart';
import '../services/websocket_service.dart';
import '../widgets/status_indicator.dart';
import '../widgets/terminal_input.dart';

/// Main terminal screen with PageView-based navigation.
///
/// Page 0: Terminal (xterm shell view)
/// Page 1+: Connected device previews (one device per page)
///
/// The status bar shows page indicator dots. The shell input section
/// is only visible when on the terminal page (page 0).
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Consumer<PreviewProvider>(
          builder: (context, previewProvider, _) {
            final devices = previewProvider.devices;
            final pageCount = 1 + devices.length;

            // If devices were removed and current page is out of bounds, reset.
            if (_currentPage >= pageCount) {
              _currentPage = 0;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_pageController.hasClients) {
                  _pageController.jumpToPage(0);
                }
              });
            }

            return Column(
              children: [
                _StatusBar(
                  currentPage: _currentPage,
                  pageCount: pageCount,
                  onDotTapped: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: VcrDurations.fadeIn,
                      curve: Curves.easeInOut,
                    );
                  },
                ),
                const Divider(height: 1, color: VcrColors.bgTertiary),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pageCount,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _ShellMainArea();
                      }
                      final device = devices[index - 1];
                      return _DevicePreviewPage(
                        device: device,
                        frameBytes:
                            previewProvider.getFrameForDevice(device.id),
                      );
                    },
                  ),
                ),
                if (_currentPage == 0) ...[
                  const Divider(height: 1, color: VcrColors.bgTertiary),
                  const _ShellInputSection(),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Status Bar (with page indicator dots)
// =============================================================================

class _StatusBar extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final ValueChanged<int> onDotTapped;

  const _StatusBar({
    required this.currentPage,
    required this.pageCount,
    required this.onDotTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VcrColors.bgSecondary,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Connection status indicator
              Consumer<PreviewProvider>(
                builder: (context, previewProvider, _) {
                  return StatusIndicator(state: previewProvider.agentState);
                },
              ),
              const SizedBox(width: Spacing.md),
              // Host IP (or "Disconnected")
              Expanded(
                child: Consumer<ConnectionProvider>(
                  builder: (context, connProvider, _) {
                    return Text(
                      connProvider.host ?? 'Disconnected',
                      style: VcrTypography.bodyMedium.copyWith(
                        color: VcrColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),
              // Claude mode badge
              Consumer<TerminalProvider>(
                builder: (context, terminalProvider, _) {
                  if (!terminalProvider.isClaudeMode) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(right: Spacing.sm),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: VcrColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.sm),
                    ),
                    child: Text(
                      'Claude',
                      style: VcrTypography.labelMedium.copyWith(
                        color: VcrColors.warning,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
              // Claude Code launch button
              Consumer<ConnectionProvider>(
                builder: (context, connProvider, _) {
                  if (!connProvider.isConnected) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: Icon(
                      Icons.auto_awesome,
                      color: VcrColors.warning,
                    ),
                    onPressed: () {
                      final wsService = context.read<WebSocketService>();
                      wsService.sendShellInput(
                        'claude --dangerously-skip-permissions\r',
                      );
                    },
                    splashRadius: 20,
                    tooltip: 'Launch Claude',
                  );
                },
              ),
              // Restart button
              Consumer<ConnectionProvider>(
                builder: (context, connProvider, _) {
                  if (!connProvider.isConnected) {
                    return const SizedBox.shrink();
                  }
                  return IconButton(
                    icon: const Icon(
                      Icons.power_settings_new,
                      color: VcrColors.error,
                    ),
                    onPressed: () {
                      final wsService = context.read<WebSocketService>();
                      wsService.reconnect();
                    },
                    splashRadius: 20,
                    tooltip: 'Restart',
                  );
                },
              ),
            ],
          ),
          // Page indicator dots (only when there are device pages)
          if (pageCount > 1) ...[
            const SizedBox(height: Spacing.xs),
            _PageIndicatorDots(
              count: pageCount,
              currentIndex: currentPage,
              onDotTapped: onDotTapped,
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Page Indicator Dots
// =============================================================================

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
                  ? (index == 0 ? VcrColors.accent : VcrColors.success)
                  : VcrColors.textMuted.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(Radii.full),
            ),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// Device Preview Page (one device per page in the PageView)
// =============================================================================

class _DevicePreviewPage extends StatelessWidget {
  final DeviceInfo device;
  final Uint8List? frameBytes;

  const _DevicePreviewPage({
    required this.device,
    required this.frameBytes,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Fullscreen device frame
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: frameBytes != null
                    ? Image.memory(
                        frameBytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      )
                    : _buildPlaceholder(),
              ),
            ),
          ),
        ),
        // Device name + LIVE overlay (top)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black54,
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.phone_android,
                  size: 16,
                  color: VcrColors.accent,
                ),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    device.name,
                    style: VcrTypography.bodyMedium.copyWith(
                      color: VcrColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
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
// Shell Main Area (xterm view + exit overlay)
// =============================================================================

class _ShellMainArea extends StatelessWidget {
  const _ShellMainArea();

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, _) {
        return Stack(
          children: [
            // xterm terminal view (always present)
            _ShellTerminalView(terminalProvider: terminalProvider),
            // Shell exit overlay (shown when shell exited)
            if (terminalProvider.shellExited)
              _ShellExitOverlay(
                exitCode: terminalProvider.shellExitCode,
                onRestart: () {
                  final wsService = context.read<WebSocketService>();
                  wsService.sendCommand('shell');
                  terminalProvider.setShellActive(true);
                },
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Shell Terminal View (xterm, always displayed)
// =============================================================================

class _ShellTerminalView extends StatefulWidget {
  final TerminalProvider terminalProvider;

  const _ShellTerminalView({required this.terminalProvider});

  @override
  State<_ShellTerminalView> createState() => _ShellTerminalViewState();
}

class _ShellTerminalViewState extends State<_ShellTerminalView> {
  Timer? _resizeDebounce;

  /// Track the last sent dimensions to avoid duplicate resize commands
  /// (e.g. when PageView rebuilds the terminal page during swipes).
  int _lastSentColumns = 0;
  int _lastSentRows = 0;

  @override
  void dispose() {
    _resizeDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terminal = widget.terminalProvider.shellTerminal;
    if (terminal == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: VcrColors.accent),
            const SizedBox(height: Spacing.md),
            Text(
              'Connecting to shell...',
              style: VcrTypography.bodyMedium.copyWith(
                color: VcrColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    final wsService = context.read<WebSocketService>();
    terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      // Skip if dimensions haven't actually changed.
      if (width == _lastSentColumns && height == _lastSentRows) return;
      // Debounce resize to avoid spamming during keyboard animation.
      _resizeDebounce?.cancel();
      _resizeDebounce = Timer(const Duration(milliseconds: 300), () {
        _lastSentColumns = width;
        _lastSentRows = height;
        wsService.sendShellResize(width, height);
      });
    };
    return TerminalView(
      terminal,
      readOnly: true,
      keyboardAppearance: Brightness.dark,
      textStyle: vcrTerminalStyle,
      theme: vcrTerminalTheme,
    );
  }
}

// =============================================================================
// Shell Exit Overlay
// =============================================================================

class _ShellExitOverlay extends StatelessWidget {
  final int? exitCode;
  final VoidCallback onRestart;

  const _ShellExitOverlay({
    required this.exitCode,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final isNormalExit = exitCode == 0;
    return Container(
      color: VcrColors.bgPrimary.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isNormalExit ? Icons.check_circle : Icons.warning,
              size: 48,
              color:
                  isNormalExit ? VcrColors.textSecondary : VcrColors.warning,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              isNormalExit
                  ? 'Shell session ended'
                  : 'Shell exited with error (code: $exitCode)',
              style: VcrTypography.bodyLarge.copyWith(
                color: VcrColors.textPrimary,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            ElevatedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart Shell'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VcrColors.accent,
                foregroundColor: VcrColors.bgPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shell Input Section (V2 — always shell mode, :vcr prefix for VCR commands)
// =============================================================================

class _ShellInputSection extends StatelessWidget {
  const _ShellInputSection();

  @override
  Widget build(BuildContext context) {
    final connProvider = context.watch<ConnectionProvider>();
    final terminalProvider = context.watch<TerminalProvider>();
    final wsService = context.read<WebSocketService>();

    final isConnected = connProvider.isConnected;
    final isShellReady = isConnected && terminalProvider.shellActive;
    final isClaudeMode = terminalProvider.isClaudeMode;

    return TerminalInput(
      enabled: isShellReady,
      commandHistory: terminalProvider.commandHistory,
      hintText: isClaudeMode ? 'Message Claude...' : 'Enter command...',
      promptText: isClaudeMode ? '\u25C6 ' : '\$ ',
      mode: isClaudeMode ? TerminalInputMode.claude : TerminalInputMode.shell,
      onTab: isShellReady
          ? () => wsService.sendShellInput('\t')
          : null,
      onEsc: isShellReady
          ? () => wsService.sendShellInput('\x1b')
          : null,
      onSubmit: (command) {
        if (command.startsWith(':vcr ')) {
          // VCR command mode (secondary)
          wsService.sendCommand(command.substring(5));
        } else {
          // Send input directly to the shell (or to Claude if it's the
          // foreground process). Works like a normal terminal — user can
          // type 'claude' to start Claude Code, 'ls' to list files, etc.
          wsService.sendShellInput('$command\r');
        }
      },
    );
  }
}
