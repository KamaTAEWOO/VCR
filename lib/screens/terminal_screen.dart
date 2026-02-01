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
import '../widgets/preview_viewer.dart';
import '../widgets/status_indicator.dart';
import '../widgets/terminal_input.dart';

/// Main terminal screen: status bar + xterm terminal view + shell input.
///
/// The xterm TerminalView is the primary output area. Shell is always active.
/// Optionally shows a mini preview panel (1/3 width) on the right.
/// Matches UI_SPEC_V2.md section 3.
class TerminalScreen extends StatelessWidget {
  const TerminalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _StatusBar(),
            const Divider(height: 1, color: VcrColors.bgTertiary),
            Expanded(
              child: Consumer<PreviewProvider>(
                builder: (context, previewProvider, _) {
                  if (previewProvider.showMiniPreview) {
                    return Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: _ShellMainArea(),
                        ),
                        Container(
                          width: 1,
                          color: VcrColors.bgTertiary,
                        ),
                        Expanded(
                          flex: 1,
                          child: _MiniPreviewPanel(
                            previewProvider: previewProvider,
                          ),
                        ),
                      ],
                    );
                  }
                  return const _ShellMainArea();
                },
              ),
            ),
            const Divider(height: 1, color: VcrColors.bgTertiary),
            const _ShellInputSection(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Status Bar (V2 — simplified: connection status + host IP + preview button)
// =============================================================================

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VcrColors.bgSecondary,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: Row(
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
          // Terminal clear button
          Consumer<TerminalProvider>(
            builder: (context, terminalProvider, _) {
              if (!terminalProvider.shellActive) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(
                  Icons.clear_all,
                  color: VcrColors.textSecondary,
                ),
                onPressed: () {
                  // Write ANSI clear screen + cursor home to the terminal
                  terminalProvider.shellTerminal?.write('\x1b[2J\x1b[H');
                },
                splashRadius: 20,
                tooltip: 'Clear terminal',
              );
            },
          ),
          // Terminal restart button
          Consumer<TerminalProvider>(
            builder: (context, terminalProvider, _) {
              if (!terminalProvider.shellActive) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(
                  Icons.restart_alt,
                  color: VcrColors.textSecondary,
                ),
                onPressed: () {
                  final wsService = context.read<WebSocketService>();
                  terminalProvider.setShellActive(false);
                  terminalProvider.setShellActive(true);
                  wsService.sendCommand('shell');
                },
                splashRadius: 20,
                tooltip: 'Restart terminal',
              );
            },
          ),
          // Disconnect button
          Consumer<ConnectionProvider>(
            builder: (context, connProvider, _) {
              if (!connProvider.isConnected) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(
                  Icons.link_off,
                  color: VcrColors.error,
                ),
                onPressed: () {
                  final wsService = context.read<WebSocketService>();
                  wsService.disconnect();
                },
                splashRadius: 20,
                tooltip: 'Disconnect',
              );
            },
          ),
          // Preview button (only when devices are connected)
          Consumer<PreviewProvider>(
            builder: (context, previewProvider, _) {
              if (previewProvider.deviceCount <= 0) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(
                  previewProvider.showMiniPreview
                      ? Icons.fullscreen_exit
                      : Icons.phone_android,
                  color: VcrColors.accent,
                ),
                onPressed: () {
                  previewProvider.toggleMiniPreview();
                },
                splashRadius: 20,
                tooltip: previewProvider.showMiniPreview
                    ? 'Hide preview'
                    : 'Show preview',
              );
            },
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
      // Debounce resize to avoid spamming during keyboard animation.
      _resizeDebounce?.cancel();
      _resizeDebounce = Timer(const Duration(milliseconds: 300), () {
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
// Mini Preview Panel (Multi-device)
// =============================================================================

class _MiniPreviewPanel extends StatelessWidget {
  final PreviewProvider previewProvider;

  const _MiniPreviewPanel({required this.previewProvider});

  @override
  Widget build(BuildContext context) {
    final devices = previewProvider.devices;

    if (devices.isEmpty) {
      // No devices -- check if we have a legacy frame
      if (previewProvider.currentFrame != null) {
        return _buildLegacySinglePreview(context);
      }
      return _buildNoDevicesMessage();
    }

    if (devices.length == 1) {
      // Single device -- show it filling the panel with fullscreen header
      return _buildSingleDevicePreview(context, devices.first);
    }

    // Multiple devices -- panel header + vertical scrollable list
    return Container(
      color: VcrColors.bgPrimary,
      child: Column(
        children: [
          // Panel header with fullscreen button
          _MiniPreviewHeader(
            deviceCount: devices.length,
            onFullscreen: () {
              Navigator.of(context).pushNamed('/preview');
            },
          ),
          // Device list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(Spacing.sm),
              itemCount: devices.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: Spacing.sm),
              itemBuilder: (context, index) {
                return _DevicePreviewCard(
                  device: devices[index],
                  frameBytes: previewProvider
                      .getFrameForDevice(devices[index].id),
                  isSelected: devices[index].id ==
                      previewProvider.selectedDeviceId,
                  onTap: () {
                    previewProvider.selectDevice(devices[index].id);
                    Navigator.of(context).pushNamed(
                      '/preview',
                      arguments: devices[index].id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Legacy single preview (backward compat: no device info, just a frame).
  Widget _buildLegacySinglePreview(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/preview');
      },
      child: Container(
        color: Colors.black,
        child: PreviewViewer(
          frameBytes: previewProvider.currentFrame,
          mini: true,
        ),
      ),
    );
  }

  /// Single device: fill the panel with the preview and a device label.
  Widget _buildSingleDevicePreview(BuildContext context, DeviceInfo device) {
    return Column(
      children: [
        // Panel header with fullscreen button
        _MiniPreviewHeader(
          deviceCount: 1,
          onFullscreen: () {
            previewProvider.selectDevice(device.id);
            Navigator.of(context).pushNamed(
              '/preview',
              arguments: device.id,
            );
          },
        ),
        // Preview filling the rest of the panel
        Expanded(
          child: GestureDetector(
            onTap: () {
              previewProvider.selectDevice(device.id);
              Navigator.of(context).pushNamed(
                '/preview',
                arguments: device.id,
              );
            },
            child: Container(
              color: Colors.black,
              child: PreviewViewer(
                frameBytes: previewProvider.getFrameForDevice(device.id),
                mini: true,
                deviceName: device.name,
                platform: device.platform,
                showDeviceLabel: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoDevicesMessage() {
    return Container(
      color: VcrColors.bgPrimary,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.devices,
              size: 32,
              color: VcrColors.textMuted,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'No devices connected',
              style: VcrTypography.labelMedium.copyWith(
                color: VcrColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Mini Preview Panel Header (with fullscreen button)
// =============================================================================

class _MiniPreviewHeader extends StatelessWidget {
  final int deviceCount;
  final VoidCallback onFullscreen;

  const _MiniPreviewHeader({
    required this.deviceCount,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      color: VcrColors.bgSecondary,
      child: Row(
        children: [
          Icon(
            Icons.devices,
            size: 14,
            color: VcrColors.textSecondary,
          ),
          const SizedBox(width: Spacing.xs),
          Text(
            '$deviceCount device${deviceCount != 1 ? 's' : ''}',
            style: VcrTypography.labelMedium.copyWith(
              color: VcrColors.textSecondary,
            ),
          ),
          const Spacer(),
          // Fullscreen viewer button
          GestureDetector(
            onTap: onFullscreen,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: VcrColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fullscreen,
                    size: 14,
                    color: VcrColors.accent,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'View',
                    style: VcrTypography.labelMedium.copyWith(
                      color: VcrColors.accent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Device Preview Card (for multi-device mini preview list)
// =============================================================================

class _DevicePreviewCard extends StatelessWidget {
  final DeviceInfo device;
  final Uint8List? frameBytes;
  final bool isSelected;
  final VoidCallback onTap;

  const _DevicePreviewCard({
    required this.device,
    required this.frameBytes,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: VcrColors.bgSecondary,
          borderRadius: BorderRadius.circular(Radii.md),
          border: isSelected
              ? Border.all(color: VcrColors.accent, width: 1.5)
              : Border.all(color: VcrColors.bgTertiary, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device label header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.xs,
              ),
              color: VcrColors.bgTertiary,
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    size: 14,
                    color: isSelected
                        ? VcrColors.accent
                        : VcrColors.textSecondary,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Text(
                      device.name,
                      style: VcrTypography.labelMedium.copyWith(
                        color: isSelected
                            ? VcrColors.accent
                            : VcrColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (device.isCapturing)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: VcrColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
            // Preview thumbnail with fullscreen hint
            AspectRatio(
              aspectRatio: 9 / 16,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: frameBytes != null
                          ? Image.memory(
                              frameBytes!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            )
                          : Center(
                              child: Icon(
                                Icons.hourglass_empty,
                                size: 20,
                                color: VcrColors.textMuted,
                              ),
                            ),
                    ),
                  ),
                  // Fullscreen hint icon (bottom-right)
                  if (frameBytes != null)
                    Positioned(
                      right: Spacing.xs,
                      bottom: Spacing.xs,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(Radii.sm),
                        ),
                        child: const Icon(
                          Icons.fullscreen,
                          size: 14,
                          color: VcrColors.textSecondary,
                        ),
                      ),
                    ),
                ],
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
      hintText: isClaudeMode ? 'Message Claude...' : 'Shell command...',
      promptText: isClaudeMode ? '\u25C6 ' : '\$ ',
      mode: isClaudeMode ? TerminalInputMode.claude : TerminalInputMode.shell,
      onSubmit: (command) {
        if (command.startsWith(':vcr ')) {
          // VCR command mode (secondary)
          wsService.sendCommand(command.substring(5));
        } else if (command.startsWith('!')) {
          // Shell escape: !ls, !git status, etc.
          wsService.sendShellInput('${command.substring(1)}\r');
        } else if (isClaudeMode) {
          // Claude is already running — send directly to its stdin.
          wsService.sendShellInput('$command\r');
        } else {
          // Claude not running — launch it with the message as prompt.
          // Escape single quotes for safe shell embedding.
          final escaped = command.replaceAll("'", "'\\''");
          wsService.sendShellInput("claude '$escaped'\r");
        }
      },
    );
  }
}
