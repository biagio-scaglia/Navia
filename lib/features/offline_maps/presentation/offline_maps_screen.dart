import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/offline_region_card.dart';
import '../domain/map_region.dart';
import 'offline_maps_controller.dart';

/// Lists the regions whose map can be stored on the device, with their
/// download state.
class OfflineMapsScreen extends ConsumerStatefulWidget {
  const OfflineMapsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const OfflineMapsScreen()));

  @override
  ConsumerState<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends ConsumerState<OfflineMapsScreen> {
  @override
  void initState() {
    super.initState();
    // Reading the catalog is a request to GitHub; it happens only when the
    // user opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(offlineMapsProvider).catalogStatus;
      if (status != MapCatalogStatus.ready) {
        unawaited(ref.read(offlineMapsProvider.notifier).loadCatalog());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(offlineMapsProvider);
    final controller = ref.read(offlineMapsProvider.notifier);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Installed regions stay listed even when the catalog is unavailable.
    final regions = [
      ...state.catalog,
      for (final installed in state.installed)
        if (!state.catalog.any((r) => r.id == installed.region.id))
          installed.region,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: const Text(AppStrings.offlineMaps),
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
              children: [
                Text(AppStrings.offlineMapsIntro, style: muted),
                const SizedBox(height: NaviaSpacing.lg),
                if (state.catalogStatus == MapCatalogStatus.loading &&
                    regions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(NaviaSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.catalogStatus == MapCatalogStatus.failed) ...[
                  Text(
                    state.catalogFailure?.message ??
                        AppStrings.offlineCatalogUnavailable,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: controller.loadCatalog,
                      child: const Text(AppStrings.retry),
                    ),
                  ),
                  const SizedBox(height: NaviaSpacing.md),
                ],
                for (final region in regions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NaviaSpacing.md),
                    child: _MapRegionCard(region: region),
                  ),
                const SizedBox(height: NaviaSpacing.md),
                Text(AppStrings.offlineMapsLicense, style: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapRegionCard extends ConsumerWidget {
  const _MapRegionCard({required this.region});

  final MapRegion region;

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmOfflineAction(
      context,
      title: AppStrings.downloadRegionTitle(region.name),
      body: AppStrings.downloadMapBody(formatBytes(region.bytes)),
      action: AppStrings.download,
    );
    if (confirmed) {
      unawaited(ref.read(offlineMapsProvider.notifier).download(region));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmOfflineAction(
      context,
      title: AppStrings.deleteMapTitle(region.name),
      body: AppStrings.deleteMapBody,
      action: AppStrings.delete,
    );
    if (confirmed) {
      await ref.read(offlineMapsProvider.notifier).delete(region.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (installed, downloading, progress, failure, inCatalog) = ref.watch(
      offlineMapsProvider.select(
        (s) => (
          s.installedRegion(region.id),
          s.progress.containsKey(region.id),
          s.progress[region.id],
          s.failures[region.id],
          s.catalog.any((r) => r.id == region.id),
        ),
      ),
    );
    final controller = ref.read(offlineMapsProvider.notifier);

    final String status;
    if (downloading) {
      status = progress == null
          ? AppStrings.installingRegion
          : AppStrings.downloadingRegion((progress * 100).round());
    } else if (installed != null) {
      status = AppStrings.regionInstalled(
        formatShortDate(installed.installedAt.toLocal()),
        formatBytes(installed.region.bytes),
      );
    } else {
      status = formatBytes(region.bytes);
    }

    return OfflineRegionCard(
      name: region.name,
      detail: region.detail,
      status: status,
      failure: failure?.message,
      installed: installed != null,
      downloading: downloading,
      progress: progress,
      canDownload: inCatalog,
      updateAvailable:
          installed != null &&
          inCatalog &&
          installed.region.sha256 != region.sha256,
      onDownload: () => _download(context, ref),
      onCancel: () => controller.cancel(region.id),
      onDelete: () => _delete(context, ref),
    );
  }
}
