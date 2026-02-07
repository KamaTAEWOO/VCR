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
  final void Function(String currentText)? onTab;
  final bool enabled;
  final bool isTabLoading;
  final List<String> commandHistory;
  final String? hintText;
  final String promptText;
  final TerminalInputMode mode;
  final ValueChanged<String>? onTextChanged;

  /// Optional external controller. If provided, the widget uses this
  /// controller instead of creating its own. The caller is responsible
  /// for disposal.
  final TextEditingController? controller;

  const TerminalInput({
    super.key,
    required this.onSubmit,
    this.onTab,
    this.enabled = true,
    this.isTabLoading = false,
    this.commandHistory = const [],
    this.hintText,
    this.promptText = '> ',
    this.mode = TerminalInputMode.shell,
    this.onTextChanged,
    this.controller,
  });

  @override
  State<TerminalInput> createState() => _TerminalInputState();
}

class _TerminalInputState extends State<TerminalInput> {
  TextEditingController? _ownController;
  final FocusNode _focusNode = FocusNode();
  int _historyIndex = -1;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _navigateHistory(true);
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          _navigateHistory(false);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _ownController?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onTextChanged?.call(_controller.text);
  }

  void _handleSubmit([String? value]) {
    final text = (value ?? _controller.text).trim();
    if (text.isEmpty) return;

    widget.onSubmit(text);
    _controller.clear();
    _historyIndex = -1;
    // Ensure keyboard stays open after submit on iOS.
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
            if (widget.onTab != null)
              widget.isTabLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VcrColors.accent,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.keyboard_tab, size: 20),
                      color: VcrColors.textSecondary,
                      onPressed: widget.enabled
                          ? () => widget.onTab!(_controller.text)
                          : null,
                      splashRadius: 20,
                      tooltip: 'Tab',
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
