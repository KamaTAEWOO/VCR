import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/terminal_entry.dart';

/// Scrollable terminal output area that displays command history and results.
///
/// Automatically scrolls to the bottom when new entries are added.
/// Matches UI_SPEC.md section 4.3.
class TerminalOutput extends StatefulWidget {
  final List<TerminalEntry> entries;

  const TerminalOutput({
    super.key,
    required this.entries,
  });

  @override
  State<TerminalOutput> createState() => _TerminalOutputState();
}

class _TerminalOutputState extends State<TerminalOutput> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(TerminalOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to bottom when new entries are added
    if (widget.entries.length > oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return Center(
        child: Text(
          'Type a command to get started.\nTry "help" for available commands.',
          textAlign: TextAlign.center,
          style: VcrTypography.terminalText.copyWith(
            color: VcrColors.textMuted,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(Spacing.md),
      itemCount: widget.entries.length,
      itemBuilder: (context, index) {
        final entry = widget.entries[index];
        final isShell = entry.type == TerminalEntryType.shellOutput;
        return Padding(
          padding: isShell ? EdgeInsets.zero : const EdgeInsets.only(bottom: Spacing.xs),
          child: _buildEntryRow(entry),
        );
      },
    );
  }

  Widget _buildEntryRow(TerminalEntry entry) {
    if (entry.type == TerminalEntryType.shellOutput) {
      return Text(
        entry.text,
        style: VcrTypography.terminalText.copyWith(
          color: VcrColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    final prefixColor = _colorForType(entry.type);
    final textColor = _textColorForType(entry.type);
    final fontWeight = _weightForType(entry.type);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: entry.prefix,
            style: VcrTypography.terminalText.copyWith(
              color: prefixColor,
              fontWeight: fontWeight,
            ),
          ),
          TextSpan(
            text: entry.text,
            style: VcrTypography.terminalText.copyWith(
              color: textColor,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorForType(TerminalEntryType type) {
    switch (type) {
      case TerminalEntryType.input:
        return VcrColors.textPrimary;
      case TerminalEntryType.success:
        return VcrColors.success;
      case TerminalEntryType.error:
        return VcrColors.error;
      case TerminalEntryType.warning:
        return VcrColors.warning;
      case TerminalEntryType.log:
        return VcrColors.textSecondary;
      case TerminalEntryType.shellOutput:
        return VcrColors.textPrimary;
    }
  }

  static Color _textColorForType(TerminalEntryType type) {
    switch (type) {
      case TerminalEntryType.input:
        return VcrColors.textPrimary;
      case TerminalEntryType.success:
        return VcrColors.success;
      case TerminalEntryType.error:
        return VcrColors.error;
      case TerminalEntryType.warning:
        return VcrColors.warning;
      case TerminalEntryType.log:
        return VcrColors.textSecondary;
      case TerminalEntryType.shellOutput:
        return VcrColors.textPrimary;
    }
  }

  static FontWeight _weightForType(TerminalEntryType type) {
    switch (type) {
      case TerminalEntryType.input:
        return FontWeight.w500;
      default:
        return FontWeight.w400;
    }
  }
}
