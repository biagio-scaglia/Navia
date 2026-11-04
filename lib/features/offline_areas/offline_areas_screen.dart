import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/navia_tokens.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/navia_buttons.dart';
import '../../core/widgets/offline_region_card.dart';
import '../offline_maps/data/map_data_client.dart';
import '../offline_maps/domain/map_region.dart';
import '../offline_maps/presentation/offline_maps_controller.dart';
import '../places/data/place_data_client.dart';
import '../places/domain/place_region.dart';
import '../places/presentation/offline_places_controller.dart';

/// The two downloads of a zone.
enum OfflinePart { map, places }

/// Lists the zones that can be stored on the device. Each zone has a map
/// and a places dataset, which the two catalogs list under the same id;
/// they can be downloaded together or one at a time.
class OfflineAreasScreen extends ConsumerStatefulWidget {
  const OfflineAreasScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const OfflineAreasScreen()));

  @override
  ConsumerState<OfflineAreasScreen> createState() => _OfflineAreasScreenState();
}

class _OfflineAreasScreenState extends ConsumerState<OfflineAreasScreen> {
  @override
  void initState() {
    super.initState();
    // Reading the catalogs is a request to GitHub; it happens only when the
    // user opens this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCatalogs();
    });
  }

  void _loadCatalogs() {
    if (ref.read(offlineMapsProvider).catalogStatus != MapCatalogStatus.ready) {
      unawaited(ref.read(offlineMapsProvider.notifier).loadCatalog());
    }
    if (ref.read(offlinePlacesProvider).catalogStatus != CatalogStatus.ready) {
      unawaited(ref.read(offlinePlacesProvider.notifier).loadCatalog());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMaps = ref.watch(mapDataClientProvider) != null;
    final hasPlaces = ref.watch(placeDataClientProvider) != null;
    final maps = ref.watch(offlineMapsProvider);
    final places = ref.watch(offlinePlacesProvider);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    // Installed zones stay listed even when the catalogs are unavailable.
    final zones = <String, String>{};
    void add(String id, String name) => zones.putIfAbsent(id, () => name);
    if (hasMaps) {
      for (final r in maps.catalog) {
        add(r.id, r.name);
      }
    }
    if (hasPlaces) {
      for (final r in places.catalog) {
        add(r.id, r.name);
      }
    }
    if (hasMaps) {
      for (final r in maps.installed) {
        add(r.region.id, r.region.name);
      }
    }
    if (hasPlaces) {
      for (final r in places.installed) {
        add(r.region.id, r.region.name);
      }
    }

    final loading =
        (hasMaps && maps.catalogStatus == MapCatalogStatus.loading) ||
        (hasPlaces && places.catalogStatus == CatalogStatus.loading);
    final failure =
        (hasMaps && maps.catalogStatus == MapCatalogStatus.failed
            ? maps.catalogFailure
            : null) ??
        (hasPlaces && places.catalogStatus == CatalogStatus.failed
            ? places.catalogFailure
            : null);
    final failed =
        (hasMaps && maps.catalogStatus == MapCatalogStatus.failed) ||
        (hasPlaces && places.catalogStatus == CatalogStatus.failed);

    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: const Text(AppStrings.offlineAreas),
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
                Text(AppStrings.offlineAreasIntro, style: muted),
                const SizedBox(height: NaviaSpacing.lg),
                if (loading && zones.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(NaviaSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (failed) ...[
                  Text(
                    failure?.message ?? AppStrings.offlineCatalogUnavailable,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _loadCatalogs,
                      child: const Text(AppStrings.retry),
                    ),
                  ),
                  const SizedBox(height: NaviaSpacing.md),
                ],
                for (final MapEntry(key: id, value: name) in zones.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NaviaSpacing.md),
                    child: _ZoneCard(
                      id: id,
                      name: name,
                      hasMaps: hasMaps,
                      hasPlaces: hasPlaces,
                    ),
                  ),
                const SizedBox(height: NaviaSpacing.md),
                Text(AppStrings.offlineAreasLicense, style: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What a zone offers for one part, and what of it is on the device.
class _PartState {
  const _PartState({
    required this.part,
    required this.offeredBytes,
    required this.installed,
    required this.updateAvailable,
    required this.downloading,
    required this.progress,
    required this.status,
    required this.option,
    this.failure,
  });

  final OfflinePart part;

  /// Size in the catalog, or null when the catalog does not offer it.
  final int? offeredBytes;
  final bool installed;
  final bool updateAvailable;
  final bool downloading;
  final double? progress;
  final String status;

  /// Label of the part in the download and delete dialogs.
  final String option;
  final String? failure;

  bool get canDownload =>
      !downloading && offeredBytes != null && (!installed || updateAvailable);
  bool get canDelete => !downloading && installed;
}

class _ZoneCard extends ConsumerWidget {
  const _ZoneCard({
    required this.id,
    required this.name,
    required this.hasMaps,
    required this.hasPlaces,
  });

  final String id;
  final String name;
  final bool hasMaps;
  final bool hasPlaces;

  static String _partStatus(
    String part, {
    required bool downloading,
    required double? progress,
    required DateTime? installedAt,
    required String installedSize,
    required String offered,
    required bool updateAvailable,
  }) {
    if (downloading) {
      return progress == null
          ? AppStrings.partInstalling(part)
          : AppStrings.partDownloading(part, (progress * 100).round());
    }
    if (installedAt != null) {
      final status = AppStrings.partInstalled(
        part,
        formatShortDate(installedAt.toLocal()),
        installedSize,
      );
      return updateAvailable ? '$status · ${AppStrings.partUpdate}' : status;
    }
    return AppStrings.partAvailable(part, offered);
  }

  _PartState _map(OfflineMapsState s) {
    final MapRegion? offered = s.catalog.where((r) => r.id == id).firstOrNull;
    final installed = s.installedRegion(id);
    final region = offered ?? installed?.region;
    final downloading = s.progress.containsKey(id);
    final update =
        installed != null &&
        offered != null &&
        installed.region.sha256 != offered.sha256;
    final size = formatBytes(region?.bytes ?? 0);
    return _PartState(
      part: OfflinePart.map,
      offeredBytes: offered?.bytes,
      installed: installed != null,
      updateAvailable: update,
      downloading: downloading,
      progress: s.progress[id],
      failure: s.failures[id]?.message,
      status: _partStatus(
        AppStrings.partMap,
        downloading: downloading,
        progress: s.progress[id],
        installedAt: installed?.installedAt,
        installedSize: formatBytes(installed?.region.bytes ?? 0),
        offered: size,
        updateAvailable: update,
      ),
      option: AppStrings.partAvailable(AppStrings.partMap, size),
    );
  }

  _PartState _places(OfflinePlacesState s) {
    final PlaceRegion? offered = s.catalog.where((r) => r.id == id).firstOrNull;
    final installed = s.installedRegion(id);
    final region = offered ?? installed?.region;
    final downloading = s.progress.containsKey(id);
    final update =
        installed != null &&
        offered != null &&
        installed.region.sha256 != offered.sha256;
    final size = AppStrings.placesSize(
      formatBytes(region?.bytes ?? 0),
      formatCount(region?.count ?? 0),
    );
    return _PartState(
      part: OfflinePart.places,
      offeredBytes: offered?.bytes,
      installed: installed != null,
      updateAvailable: update,
      downloading: downloading,
      progress: s.progress[id],
      failure: s.failures[id]?.message,
      status: _partStatus(
        AppStrings.partPlaces,
        downloading: downloading,
        progress: s.progress[id],
        installedAt: installed?.installedAt,
        installedSize: formatBytes(installed?.bytesOnDisk ?? 0),
        offered: size,
        updateAvailable: update,
      ),
      option: AppStrings.partAvailable(AppStrings.partPlaces, size),
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    List<_PartState> parts,
  ) async {
    final chosen = await _chooseParts(
      context,
      title: AppStrings.downloadRegionTitle(name),
      body: AppStrings.downloadZoneBody,
      action: AppStrings.download,
      parts: [
        for (final part in parts)
          if (part.canDownload) part,
      ],
    );
    if (chosen.contains(OfflinePart.map)) {
      final region = ref
          .read(offlineMapsProvider)
          .catalog
          .firstWhere((r) => r.id == id);
      unawaited(ref.read(offlineMapsProvider.notifier).download(region));
    }
    if (chosen.contains(OfflinePart.places)) {
      final region = ref
          .read(offlinePlacesProvider)
          .catalog
          .firstWhere((r) => r.id == id);
      unawaited(ref.read(offlinePlacesProvider.notifier).download(region));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<_PartState> parts,
  ) async {
    final chosen = await _chooseParts(
      context,
      title: AppStrings.deleteZoneTitle(name),
      body: AppStrings.deleteZoneBody,
      action: AppStrings.delete,
      parts: [
        for (final part in parts)
          if (part.canDelete) part,
      ],
    );
    if (chosen.contains(OfflinePart.map)) {
      await ref.read(offlineMapsProvider.notifier).delete(id);
    }
    if (chosen.contains(OfflinePart.places)) {
      await ref.read(offlinePlacesProvider.notifier).delete(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = [
      if (hasMaps) _map(ref.watch(offlineMapsProvider)),
      if (hasPlaces) _places(ref.watch(offlinePlacesProvider)),
    ];
    final downloading = parts.where((p) => p.downloading).toList();
    final progressValues = [for (final p in downloading) p.progress];
    final toDownload = parts.where((p) => p.canDownload).toList();
    final regionDetail =
        ref
            .watch(offlineMapsProvider)
            .catalog
            .where((r) => r.id == id)
            .firstOrNull
            ?.detail ??
        ref
            .watch(offlinePlacesProvider)
            .catalog
            .where((r) => r.id == id)
            .firstOrNull
            ?.detail ??
        '';

    return OfflineRegionCard(
      name: name,
      detail: regionDetail,
      status: [for (final p in parts) p.status].join('\n'),
      failure: parts.map((p) => p.failure).nonNulls.firstOrNull,
      complete: parts.isNotEmpty && parts.every((p) => p.installed),
      downloading: downloading.isNotEmpty,
      // The average of the running downloads; null while one installs.
      progress: progressValues.contains(null)
          ? null
          : progressValues.fold<double>(0, (sum, p) => sum + p!) /
                progressValues.length,
      downloadLabel: toDownload.isEmpty
          ? null
          : toDownload.every((p) => p.installed)
          ? AppStrings.updateRegion
          : AppStrings.download,
      onDownload: () => _download(context, ref, parts),
      onCancel: () {
        ref.read(offlineMapsProvider.notifier).cancel(id);
        ref.read(offlinePlacesProvider.notifier).cancel(id);
      },
      onDelete: parts.any((p) => p.canDelete)
          ? () => _delete(context, ref, parts)
          : null,
    );
  }
}

/// Asks which [parts] to act on, all checked at first; empty when
/// cancelled.
Future<Set<OfflinePart>> _chooseParts(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required List<_PartState> parts,
}) async {
  if (parts.isEmpty) return const {};
  final chosen = await showDialog<Set<OfflinePart>>(
    context: context,
    builder: (context) =>
        _PartsDialog(title: title, body: body, action: action, parts: parts),
  );
  return chosen ?? const {};
}

class _PartsDialog extends StatefulWidget {
  const _PartsDialog({
    required this.title,
    required this.body,
    required this.action,
    required this.parts,
  });

  final String title;
  final String body;
  final String action;
  final List<_PartState> parts;

  @override
  State<_PartsDialog> createState() => _PartsDialogState();
}

class _PartsDialogState extends State<_PartsDialog> {
  late final Set<OfflinePart> _chosen = {
    for (final part in widget.parts) part.part,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
            const SizedBox(height: NaviaSpacing.sm),
            for (final part in widget.parts)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _chosen.contains(part.part),
                title: Text(part.option),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _chosen.add(part.part);
                  } else {
                    _chosen.remove(part.part);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(<OfflinePart>{}),
          child: const Text(AppStrings.cancel),
        ),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop({..._chosen}),
          child: Text(widget.action),
        ),
      ],
    );
  }
}
