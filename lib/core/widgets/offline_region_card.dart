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
    required this.complete,
    required this.downloading,
    required this.progress,
    required this.onDownload,
    required this.onCancel,
    this.downloadLabel,
    this.onDelete,
    this.failure,
  });

  final String name;
  final String detail;

  /// Lines about the size, the download or the installed data.
  final String status;

  /// Error of the last download, if it failed.
  final String? failure;

  /// Everything offered for the region is on the device.
  final bool complete;
  final bool downloading;

  /// From 0 to 1, or null while the data is being installed.
  final double? progress;

  /// Label of the download button; null when there is nothing to download.
  final String? downloadLabel;

  final VoidCallback onDownload;
  final VoidCallback onCancel;

  /// Null when nothing can be deleted.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final failure = this.failure;
    final downloadLabel = this.downloadLabel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaviaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NaviaIconBadge(complete ? NaviaIcons.check : NaviaIcons.layers),
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
                if (!downloading && onDelete != null)
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const NaviaIcon(NaviaIcons.trash, size: 20),
                    label: const Text(AppStrings.delete),
                  ),
                if (!downloading && downloadLabel != null)
                  FilledButton(
                    onPressed: onDownload,
                    child: Text(downloadLabel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
