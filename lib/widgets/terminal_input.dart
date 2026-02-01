import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Input mode determines the visual style of the input bar.
enum TerminalInputMode {
  /// Default shell mode (accent/purple prompt).
  shell,

  /// Claude AI mode (amber prompt, warm background).
  claude,
}

/// CLI-style command input bar with prompt, text field, and send button.
///
/// Matches UI_SPEC.md section 4.2.
class TerminalInput extends StatefulWidget {
  final void Function(String command) onSubmit;
  final VoidCallback? onEsc;
  final VoidCallback? onTab;
  final bool enabled;
  final List<String> commandHistory;
  final String? hintText;
  final String promptText;
  final TerminalInputMode mode;

  const TerminalInput({
    super.key,
    required this.onSubmit,
    this.onEsc,
    this.onTab,
    this.enabled = true,
    this.commandHistory = const [],
    this.hintText,
    this.promptText = '> ',
    this.mode = TerminalInputMode.shell,
  });

  @override
  State<TerminalInput> createState() => _TerminalInputState();
}

class _TerminalInputState extends State<TerminalInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _historyIndex = -1;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;

    widget.onSubmit(text);
    _controller.clear();
    _historyIndex = -1;
    // Ensure keyboard stays open after submit on iOS.
    // Use a microtask to re-request focus after the framework
    // processes the onSubmitted dismiss.
    Future.microtask(() {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _navigateHistory(bool up) {
    if (widget.commandHistory.isEmpty) return;

    setState(() {
      if (up) {
        if (_historyIndex < widget.commandHistory.length - 1) {
          _historyIndex++;
        }
      } else {
        if (_historyIndex > 0) {
          _historyIndex--;
        } else {
          _historyIndex = -1;
          _controller.clear();
          return;
        }
      }

      if (_historyIndex >= 0 && _historyIndex < widget.commandHistory.length) {
        final cmd = widget.commandHistory[
            widget.commandHistory.length - 1 - _historyIndex];
        _controller.text = cmd;
        _controller.selection =
            TextSelection.fromPosition(TextPosition(offset: cmd.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isClaude = widget.mode == TerminalInputMode.claude;
    final promptColor = isClaude ? VcrColors.warning : VcrColors.accent;
    final bgColor = isClaude
        ? const Color(0xFF1A1814) // warm-tinted dark background
        : VcrColors.bgTertiary;

    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              widget.promptText,
              style: VcrTypography.terminalPrompt.copyWith(
                color: promptColor,
              ),
            ),
            Expanded(
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _navigateHistory(true);
                    } else if (event.logicalKey ==
                        LogicalKeyboardKey.arrowDown) {
                      _navigateHistory(false);
                    }
                  }
                },
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  style: VcrTypography.terminalInput,
                  decoration: InputDecoration.collapsed(
                    hintText: widget.enabled
                        ? (widget.hintText ?? 'Enter command...')
                        : 'Disconnected...',
                    hintStyle:
                        const TextStyle(color: VcrColors.textMuted),
                  ),
                  cursorColor: promptColor,
                  onSubmitted: (_) => _handleSubmit(),
                  textInputAction: TextInputAction.send,
                ),
              ),
            ),
            if (widget.onTab != null)
              IconButton(
                icon: const Icon(Icons.keyboard_tab, size: 20),
                color: VcrColors.textSecondary,
                onPressed: widget.enabled ? widget.onTab : null,
                splashRadius: 20,
                tooltip: 'Tab',
              ),
            if (widget.onEsc != null)
              IconButton(
                icon: const Icon(Icons.cancel_outlined, size: 20),
                color: VcrColors.textSecondary,
                onPressed: widget.enabled ? widget.onEsc : null,
                splashRadius: 20,
                tooltip: 'Esc',
              ),
            IconButton(
              icon: Icon(Icons.send, color: promptColor),
              onPressed: widget.enabled ? () => _handleSubmit() : null,
              splashRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}
