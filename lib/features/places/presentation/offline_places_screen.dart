import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/navia_icon.dart';
import '../data/fuel_prices_store.dart';
import '../domain/place_region.dart';
import 'offline_places_controller.dart';
import 'widgets/fuel_prices_section.dart';

/// Lists the regions whose places can be stored on the device, with their
/// download state.
class OfflinePlacesScreen extends ConsumerStatefulWidget {
  const OfflinePlacesScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const OfflinePlacesScreen()));

  @override
  ConsumerState<OfflinePlacesScreen> createState() =>
      _OfflinePlacesScreenState();
}

class _OfflinePlacesScreenState extends ConsumerState<OfflinePlacesScreen> {
  @override
  void initState() {
    super.initState();
    // Reading the catalog is a request to GitHub; it happens only when the
    // user opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = ref.read(offlinePlacesProvider).catalogStatus;
      if (status != CatalogStatus.ready) {
        unawaited(ref.read(offlinePlacesProvider.notifier).loadCatalog());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(offlinePlacesProvider);
    final controller = ref.read(offlinePlacesProvider.notifier);
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
        title: const Text(AppStrings.offlinePlaces),
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
                Text(AppStrings.offlinePlacesIntro, style: muted),
                const SizedBox(height: NaviaSpacing.lg),
                if (ref.watch(fuelPricesStoreProvider) != null) ...[
                  const FuelDataCard(),
                  const SizedBox(height: NaviaSpacing.md),
                ],
                if (state.catalogStatus == CatalogStatus.loading &&
                    regions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(NaviaSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.catalogStatus == CatalogStatus.failed) ...[
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
                    child: _RegionCard(region: region),
                  ),
                const SizedBox(height: NaviaSpacing.md),
                Text(AppStrings.offlinePlacesLicense, style: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionCard extends ConsumerWidget {
  const _RegionCard({required this.region});

  final PlaceRegion region;

  Future<void> _download(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.downloadRegionTitle(region.name)),
        content: Text(
          AppStrings.downloadRegionBody(
            formatBytes(region.bytes),
            formatCount(region.count),
          ),
        ),
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
      unawaited(ref.read(offlinePlacesProvider.notifier).download(region));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deleteRegionTitle(region.name)),
        content: const Text(AppStrings.deleteRegionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await ref.read(offlinePlacesProvider.notifier).delete(region.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final (installed, downloading, progress, failure, inCatalog) = ref.watch(
      offlinePlacesProvider.select(
        (s) => (
          s.installedRegion(region.id),
          s.progress.containsKey(region.id),
          s.progress[region.id],
          s.failures[region.id],
          s.catalog.any((r) => r.id == region.id),
        ),
      ),
    );
    final controller = ref.read(offlinePlacesProvider.notifier);
    final updateAvailable =
        installed != null &&
        inCatalog &&
        installed.region.sha256 != region.sha256;

    final String status;
    if (downloading) {
      status = progress == null
          ? AppStrings.installingRegion
          : AppStrings.downloadingRegion((progress * 100).round());
    } else if (installed != null) {
      status = AppStrings.regionInstalled(
        formatShortDate(installed.installedAt.toLocal()),
        formatBytes(installed.bytesOnDisk),
      );
    } else {
      status = AppStrings.regionAvailable(
        formatBytes(region.bytes),
        formatCount(region.count),
      );
    }

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
                  installed != null ? NaviaIcons.check : NaviaIcons.layers,
                ),
                const SizedBox(width: NaviaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(region.name, style: theme.textTheme.titleMedium),
                      if (region.detail.isNotEmpty)
                        Text(region.detail, style: muted),
                      const SizedBox(height: NaviaSpacing.xs),
                      Semantics(
                        liveRegion: downloading,
                        child: Text(status, style: theme.textTheme.bodySmall),
                      ),
                      if (failure != null)
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
                    onPressed: () => controller.cancel(region.id),
                    child: const Text(AppStrings.cancel),
                  ),
                if (!downloading && installed != null)
                  OutlinedButton.icon(
                    onPressed: () => _delete(context, ref),
                    icon: const NaviaIcon(NaviaIcons.trash, size: 20),
                    label: const Text(AppStrings.delete),
                  ),
                if (!downloading &&
                    inCatalog &&
                    (installed == null || updateAvailable))
                  FilledButton(
                    onPressed: () => _download(context, ref),
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
