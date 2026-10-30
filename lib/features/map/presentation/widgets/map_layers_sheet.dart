import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/navia_icon.dart';
import '../../../../core/widgets/navia_sheet.dart';
import '../../domain/map_style_source.dart';
import '../map_preferences_controller.dart';
import '../map_providers.dart';

/// Opens the map appearance and 3D selector.
Future<void> showMapLayersSheet(BuildContext context) => showNaviaSheet<void>(
  context,
  title: AppStrings.mapAppearance,
  builder: (_) => const _MapLayersContent(),
);

extension MapAppearanceLabels on MapAppearance {
  String get label => switch (this) {
    MapAppearance.automatic => AppStrings.appearanceAutomatic,
    MapAppearance.standard => AppStrings.appearanceStandard,
    MapAppearance.vivid => AppStrings.appearanceVivid,
    MapAppearance.minimal => AppStrings.appearanceMinimal,
    MapAppearance.dark => AppStrings.appearanceDark,
  };

  String get detail => switch (this) {
    MapAppearance.automatic => AppStrings.appearanceAutomaticDetail,
    MapAppearance.standard => AppStrings.appearanceStandardDetail,
    MapAppearance.vivid => AppStrings.appearanceVividDetail,
    MapAppearance.minimal => AppStrings.appearanceMinimalDetail,
    MapAppearance.dark => AppStrings.appearanceDarkDetail,
  };

  /// Representative land, road and water colors of the style, used as a
  /// small swatch. Automatic shows half light, half dark.
  List<Color> get swatch => switch (this) {
    MapAppearance.automatic => const [
      Color(0xFFF8F4F0),
      Color(0xFF1C2433),
      Color(0xFF9FC6E8),
    ],
    MapAppearance.standard => const [
      Color(0xFFF8F4F0),
      Color(0xFFFFFFFF),
      Color(0xFF9FC6E8),
    ],
    MapAppearance.vivid => const [
      Color(0xFFF8F4F0),
      Color(0xFFFFCC88),
      Color(0xFF7EB6E3),
    ],
    MapAppearance.minimal => const [
      Color(0xFFF2F3F0),
      Color(0xFFFFFFFF),
      Color(0xFFC2C8CA),
    ],
    MapAppearance.dark => const [
      Color(0xFF1C2433),
      Color(0xFF3A465C),
      Color(0xFF0E1726),
    ],
  };
}

class _MapLayersContent extends ConsumerWidget {
  const _MapLayersContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final source = ref.watch(mapStyleSourceProvider);
    final preferences = ref.watch(mapPreferencesProvider);
    final controller = ref.read(mapPreferencesProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final appearance in MapAppearance.values)
          if (source.supports(appearance))
            _AppearanceTile(
              appearance: appearance,
              selected: appearance == preferences.appearance,
              onTap: () => controller.setAppearance(appearance),
            ),
        const SizedBox(height: NaviaSpacing.md),
        const Divider(),
        SwitchListTile(
          secondary: const NaviaIcon(NaviaIcons.cube),
          title: const Text(AppStrings.buildings3d),
          subtitle: Text(
            source.supportsBuildings3d
                ? AppStrings.buildings3dDetail
                : AppStrings.buildings3dUnavailable,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          value: preferences.buildings3d && source.supportsBuildings3d,
          onChanged: source.supportsBuildings3d
              ? controller.setBuildings3d
              : null,
        ),
        const SizedBox(height: NaviaSpacing.sm),
        Text(
          '${AppStrings.mapProvider}: ${source.name} · © OpenStreetMap',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({
    required this.appearance,
    required this.selected,
    required this.onTap,
  });

  final MapAppearance appearance;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: NaviaSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? scheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: NaviaRadii.mdAll,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: NaviaRadii.mdAll,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(NaviaSpacing.md),
              child: Row(
                children: [
                  _Swatch(colors: appearance.swatch),
                  const SizedBox(width: NaviaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appearance.label,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          appearance.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // The check mark makes the selection visible without
                  // relying on color alone.
                  if (selected)
                    NaviaIcon(NaviaIcons.check, color: scheme.primary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: NaviaRadii.smAll,
        child: SizedBox.square(
          dimension: 44,
          child: CustomPaint(painter: _SwatchPainter(colors)),
        ),
      ),
    );
  }
}

/// Land background with a diagonal road and a water corner.
class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final [land, road, water] = colors;
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.55, size.height)
        ..lineTo(size.width, size.height * 0.5)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = water,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.75),
      Offset(size.width, size.height * 0.15),
      Paint()
        ..color = road
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SwatchPainter oldDelegate) =>
      !identical(oldDelegate.colors, colors);
}
