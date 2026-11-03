import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/offline_region_card.dart';
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
    final confirmed = await confirmOfflineAction(
      context,
      title: AppStrings.downloadRegionTitle(region.name),
      body: AppStrings.downloadRegionBody(
        formatBytes(region.bytes),
        formatCount(region.count),
      ),
      action: AppStrings.download,
    );
    if (confirmed) {
      unawaited(ref.read(offlinePlacesProvider.notifier).download(region));
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmOfflineAction(
      context,
      title: AppStrings.deleteRegionTitle(region.name),
      body: AppStrings.deleteRegionBody,
      action: AppStrings.delete,
    );
    if (confirmed) {
      await ref.read(offlinePlacesProvider.notifier).delete(region.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
