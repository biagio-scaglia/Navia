import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/navia_icon.dart';
import 'transit_controller.dart';

/// Asks before the first download of AMTAB's timetables, then starts it.
Future<void> confirmTransitDownload(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(AppStrings.amtabDownloadTitle),
      content: const Text(AppStrings.amtabDownloadBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(AppStrings.download),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    unawaited(ref.read(transitProvider.notifier).download());
  }
}

/// AMTAB's timetables: download, update and delete.
class TransitScreen extends StatelessWidget {
  const TransitScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const TransitScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: const Text(AppStrings.amtabTimetables),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                NaviaSpacing.lg,
                NaviaSpacing.sm,
                NaviaSpacing.lg,
                NaviaSpacing.xxl,
              ),
              children: const [TransitDataCard()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Download state of AMTAB's timetables.
class TransitDataCard extends ConsumerWidget {
  const TransitDataCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(transitProvider);
    final controller = ref.read(transitProvider.notifier);
    final info = state.info;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(NaviaSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NaviaIconBadge(NaviaIcons.bus),
                const SizedBox(width: NaviaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.amtabTimetables,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(AppStrings.amtabTimetablesDetail, style: muted),
                      const SizedBox(height: NaviaSpacing.xs),
                      Semantics(
                        liveRegion: state.downloading,
                        child: Text(
                          state.processing
                              ? AppStrings.amtabProcessing
                              : state.downloading
                              ? AppStrings.downloadingRegion(
                                  ((state.progress ?? 0) * 100).round(),
                                )
                              : info == null
                              ? AppStrings.amtabNotDownloaded
                              : AppStrings.amtabInstalled(
                                  formatShortDate(info.validUntil),
                                  formatBytes(info.bytes),
                                ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (state.failure case final failure?)
                        Text(
                          failure.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (state.downloading) ...[
              const SizedBox(height: NaviaSpacing.md),
              ClipRRect(
                borderRadius: NaviaRadii.pill,
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: state.processing ? null : state.progress,
                ),
              ),
            ],
            const SizedBox(height: NaviaSpacing.md),
            Text(AppStrings.amtabSource, style: muted),
            const SizedBox(height: NaviaSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: NaviaSpacing.sm,
              children: [
                if (state.processing)
                  const SizedBox.shrink()
                else if (state.downloading)
                  TextButton(
                    onPressed: controller.cancel,
                    child: const Text(AppStrings.cancel),
                  )
                else ...[
                  if (info != null)
                    OutlinedButton.icon(
                      onPressed: controller.delete,
                      icon: const NaviaIcon(NaviaIcons.trash, size: 20),
                      label: const Text(AppStrings.delete),
                    ),
                  FilledButton(
                    onPressed: info == null
                        ? () => confirmTransitDownload(context, ref)
                        : controller.download,
                    child: Text(
                      info == null
                          ? AppStrings.download
                          : AppStrings.updateRegion,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
