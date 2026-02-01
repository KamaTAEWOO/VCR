import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// A tile representing a discovered VCR Agent server.
///
/// Matches UI_SPEC.md section 4.5.
class ServerListTile extends StatelessWidget {
  final String name;
  final String host;
  final int port;
  final VoidCallback onTap;

  const ServerListTile({
    super.key,
    required this.name,
    required this.host,
    required this.port,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VcrColors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: ListTile(
        leading: const Icon(Icons.computer, color: VcrColors.accent),
        title: Text(name, style: VcrTypography.bodyLarge),
        subtitle: Text(
          '$host:$port',
          style: VcrTypography.bodyMedium.copyWith(
            color: VcrColors.textSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: VcrColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
