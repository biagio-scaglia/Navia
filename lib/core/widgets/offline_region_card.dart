import 'package:flutter/material.dart';

import '../../app/theme/navia_tokens.dart';
import '../l10n/app_strings.dart';
import 'navia_buttons.dart';
import 'navia_icon.dart';

/// A downloadable region of offline data, with its state and actions.
class OfflineRegionCard extends StatelessWidget {
  const OfflineRegionCard({
    super.key,
    required this.name,
    required this.detail,
    required this.status,
    required this.installed,
    required this.downloading,
    required this.progress,
    required this.canDownload,
    required this.updateAvailable,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    this.failure,
  });

  final String name;
  final String detail;

  /// One line about the size, the download or the installed data.
  final String status;

  /// Error of the last download, if it failed.
  final String? failure;

  final bool installed;
  final bool downloading;

  /// From 0 to 1, or null while the data is being installed.
  final double? progress;

  /// Whether the region is in the current catalog.
  final bool canDownload;
  final bool updateAvailable;

  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final failure = this.failure;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaviaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NaviaIconBadge(
                  installed ? NaviaIcons.check : NaviaIcons.layers,
                ),
                const SizedBox(width: NaviaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleMedium),
                      if (detail.isNotEmpty) Text(detail, style: muted),
                      const SizedBox(height: NaviaSpacing.xs),
                      Semantics(
                        liveRegion: downloading,
                        child: Text(status, style: theme.textTheme.bodySmall),
                      ),
                      if (failure != null)
                        Text(
                          failure,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: NaviaSpacing.md),
              ClipRRect(
                borderRadius: NaviaRadii.pill,
                child: LinearProgressIndicator(minHeight: 6, value: progress),
              ),
            ],
            const SizedBox(height: NaviaSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: NaviaSpacing.sm,
              runSpacing: NaviaSpacing.sm,
              children: [
                if (downloading && progress != null)
                  TextButton(
                    onPressed: onCancel,
                    child: const Text(AppStrings.cancel),
                  ),
                if (!downloading && installed)
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const NaviaIcon(NaviaIcons.trash, size: 20),
                    label: const Text(AppStrings.delete),
                  ),
                if (!downloading &&
                    canDownload &&
                    (!installed || updateAvailable))
                  FilledButton(
                    onPressed: onDownload,
                    child: Text(
                      updateAvailable
                          ? AppStrings.updateRegion
                          : AppStrings.download,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks to confirm a download or a deletion; true when confirmed.
Future<bool> confirmOfflineAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
