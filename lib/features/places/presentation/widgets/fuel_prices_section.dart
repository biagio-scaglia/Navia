import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/navia_buttons.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../domain/fuel.dart';
import '../fuel_prices_controller.dart';

/// Ministry prices of a fuel station: self service and served prices per
/// fuel, with the report date and source.
class FuelPricesSection extends StatelessWidget {
  const FuelPricesSection({super.key, required this.station});

  final FuelStation station;

  static const _order = ['Benzina', 'Gasolio', 'GPL', 'Metano'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final fuels = {for (final price in station.prices) price.fuel}.toList()
      ..sort((a, b) {
        final ia = _order.indexOf(a), ib = _order.indexOf(b);
        if (ia != ib) return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
        return a.compareTo(b);
      });
    final latest = station.prices
        .map((p) => p.reportedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    String? price(String fuel, {required bool self}) {
      for (final p in station.prices) {
        if (p.fuel == fuel && p.selfService == self) {
          return '${p.price.toStringAsFixed(3).replaceAll('.', ',')} €';
        }
      }
      return null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: NaviaSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          borderRadius: NaviaRadii.mdAll,
        ),
        child: Padding(
          padding: const EdgeInsets.all(NaviaSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppStrings.fuelPrices,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: NaviaSpacing.xs),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(),
                  2: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    children: [
                      const SizedBox.shrink(),
                      Text(AppStrings.fuelSelf, style: muted),
                      Text(AppStrings.fuelServed, style: muted),
                    ],
                  ),
                  for (final fuel in fuels)
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(fuel, style: theme.textTheme.bodyMedium),
                        ),
                        Text(
                          price(fuel, self: true) ?? '–',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          price(fuel, self: false) ?? '–',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: NaviaSpacing.sm),
              Text(
                AppStrings.fuelReported(formatShortDate(latest)),
                style: muted,
              ),
              Text(AppStrings.fuelSource, style: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Download state of the daily fuel prices, in the offline places screen.
class FuelDataCard extends ConsumerWidget {
  const FuelDataCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(fuelPricesProvider);
    final controller = ref.read(fuelPricesProvider.notifier);
    final info = state.info;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    Future<void> confirmDownload() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(AppStrings.fuelDownloadTitle),
          content: const Text(AppStrings.fuelDownloadBody),
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
      if (confirmed ?? false) unawaited(controller.download());
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
                const NaviaIconBadge(NaviaIcons.fuel),
                const SizedBox(width: NaviaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.fuelPricesTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(AppStrings.fuelPricesDetail, style: muted),
                      const SizedBox(height: NaviaSpacing.xs),
                      Text(
                        state.downloading
                            ? AppStrings.downloadingRegion(
                                ((state.progress ?? 0) * 100).round(),
                              )
                            : info == null
                            ? AppStrings.fuelNotDownloaded
                            : AppStrings.fuelInstalled(
                                formatShortDate(info.extracted),
                                formatBytes(info.bytes),
                              ),
                        style: theme.textTheme.bodySmall,
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
                  value: state.progress,
                ),
              ),
            ],
            const SizedBox(height: NaviaSpacing.md),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: NaviaSpacing.sm,
              children: [
                if (state.downloading)
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
                    onPressed: confirmDownload,
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
