import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/config/app_config.dart';
import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/open_link.dart';
import '../../../core/widgets/navia_logo.dart';
import '../../location/data/geolocator_location_repository.dart';
import '../../location/domain/location_models.dart';
import '../../location/presentation/location_controller.dart';
import '../../map/presentation/map_providers.dart';
import '../../map/presentation/widgets/map_attribution.dart';
import '../data/app_info_provider.dart';
import '../domain/theme_preference.dart';
import 'theme_preference_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // The permission may change in the system settings while we are away.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.invalidate(locationAccessProvider),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
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
              children: const [
                _Section(title: AppStrings.appearance, child: _ThemeSelector()),
                _Section(title: AppStrings.location, child: _LocationSection()),
                _Section(title: AppStrings.map, child: _MapSection()),
                _Section(title: AppStrings.about, child: _AboutSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: NaviaSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: NaviaSpacing.xs,
              bottom: NaviaSpacing.sm,
            ),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: NaviaSpacing.sm),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    return Padding(
      padding: const EdgeInsets.all(NaviaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: NaviaSpacing.xs,
              bottom: NaviaSpacing.md,
            ),
            child: Text(
              AppStrings.theme,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SegmentedButton<ThemePreference>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemePreference.system,
                label: Text(AppStrings.themeSystem),
                icon: Icon(Icons.brightness_auto_outlined),
              ),
              ButtonSegment(
                value: ThemePreference.light,
                label: Text(AppStrings.themeLight),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemePreference.dark,
                label: Text(AppStrings.themeDark),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {preference},
            onSelectionChanged: (selection) => ref
                .read(themePreferenceProvider.notifier)
                .select(selection.single),
          ),
        ],
      ),
    );
  }
}

class _LocationSection extends ConsumerWidget {
  const _LocationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final access = ref.watch(locationAccessProvider);
    final status = switch (access) {
      AsyncData(value: LocationAccess.granted) => AppStrings.locationGranted,
      AsyncData(value: LocationAccess.denied) => AppStrings.locationDenied,
      AsyncData(value: LocationAccess.deniedForever) =>
        AppStrings.locationDeniedForever,
      AsyncError() => AppStrings.locationStatusUnknown,
      _ => '…',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NaviaSpacing.lg,
            NaviaSpacing.sm,
            NaviaSpacing.lg,
            NaviaSpacing.sm,
          ),
          child: Text(
            AppStrings.locationInfo,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text(AppStrings.locationStatus),
          trailing: Text(status, style: theme.textTheme.labelLarge),
        ),
        ListTile(
          leading: const Icon(Icons.tune_rounded),
          title: const Text(AppStrings.manageInSystemSettings),
          trailing: const Icon(Icons.open_in_new_rounded, size: 20),
          onTap: () => ref.read(locationRepositoryProvider).openAppSettings(),
        ),
      ],
    );
  }
}

class _MapSection extends ConsumerWidget {
  const _MapSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(mapStyleSourceProvider);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.layers_outlined),
          title: const Text(AppStrings.mapProvider),
          trailing: Text(
            source.name,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const Divider(indent: NaviaSpacing.lg, endIndent: NaviaSpacing.lg),
        MapAttributionList(source: source),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final version = ref.watch(appVersionProvider).value;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: const Text(AppStrings.privacy),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: NaviaSpacing.xs),
            child: Text(
              AppStrings.privacyInfo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.code_rounded),
          title: const Text(AppStrings.sourceCode),
          subtitle: Text(Uri.parse(AppConfig.sourceCodeUrl).path.substring(1)),
          trailing: const Icon(Icons.open_in_new_rounded, size: 20),
          onTap: () => openExternalLink(context, AppConfig.sourceCodeUrl),
        ),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text(AppStrings.openSourceLicenses),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => showLicensePage(
            context: context,
            applicationName: AppConfig.appName,
            applicationVersion: version,
            applicationIcon: const Padding(
              padding: EdgeInsets.all(NaviaSpacing.md),
              child: NaviaLogoMark(size: 56),
            ),
            applicationLegalese: AppStrings.appLegalese,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text(AppStrings.version),
          trailing: Text(version ?? '…', style: theme.textTheme.labelLarge),
        ),
      ],
    );
  }
}
