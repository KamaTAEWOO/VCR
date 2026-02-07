import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../providers/terminal_provider.dart';

/// Horizontal scrollable chip bar showing tab-completion suggestions.
///
/// Displayed above the terminal input bar when multiple completion
/// candidates are available.
class AutocompleteSuggestionBar extends StatelessWidget {
  final List<CompletionItem> suggestions;
  final void Function(CompletionItem) onSelect;

  const AutocompleteSuggestionBar({
    super.key,
    required this.suggestions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VcrColors.bgSecondary,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: suggestions.map((item) {
            return Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: _SuggestionChip(
                item: item,
                onTap: () => onSelect(item),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final CompletionItem item;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDir = item.isDirectory;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        splashColor: VcrColors.accent.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: VcrColors.bgTertiary,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: isDir
                  ? VcrColors.accent.withValues(alpha: 0.3)
                  : VcrColors.textMuted.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDir ? Icons.folder : Icons.insert_drive_file,
                size: 14,
                color: isDir ? VcrColors.accent : VcrColors.textSecondary,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                item.name,
                style: VcrTypography.bodyMedium.copyWith(
                  color: isDir
                      ? VcrColors.textPrimary
                      : VcrColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
