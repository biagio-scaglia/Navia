import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/navia_icon.dart';
import '../domain/place.dart';
import 'search_controller.dart';

/// What the user picked in the search screen.
sealed class SearchPick {
  const SearchPick();
}

final class PlacePick extends SearchPick {
  const PlacePick(this.place);
  final Place place;
}

final class CurrentLocationPick extends SearchPick {
  const CurrentLocationPick();
}

/// Fullscreen place search. Pops with a [SearchPick], or null if dismissed.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({
    super.key,
    this.hint = AppStrings.searchHint,
    this.offerCurrentLocation = false,
  });

  final String hint;

  /// Shows "La tua posizione" as the first option, e.g. for the origin.
  final bool offerCurrentLocation;

  static Future<SearchPick?> open(
    BuildContext context, {
    String hint = AppStrings.searchHint,
    bool offerCurrentLocation = false,
  }) {
    return Navigator.of(context).push<SearchPick>(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          hint: hint,
          offerCurrentLocation: offerCurrentLocation,
        ),
      ),
    );
  }

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _clear() {
    _textController.clear();
    ref.read(searchControllerProvider.notifier).updateQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loading = ref.watch(
      searchControllerProvider.select((s) => s.status == SearchStatus.loading),
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: const NaviaBackButton(),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: NaviaSpacing.lg),
          child: TextField(
            controller: _textController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: NaviaSpacing.md,
                ),
                child: NaviaIcon(
                  NaviaIcons.search,
                  color: theme.colorScheme.primary,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 48),
              suffixIcon: ListenableBuilder(
                listenable: _textController,
                builder: (context, _) => _textController.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: AppStrings.clearSearch,
                        onPressed: _clear,
                        icon: const NaviaIcon(NaviaIcons.close, size: 20),
                      ),
              ),
            ),
            onChanged: ref.read(searchControllerProvider.notifier).updateQuery,
            onSubmitted: ref.read(searchControllerProvider.notifier).submit,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: loading
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _SearchResults(
                offerCurrentLocation: widget.offerCurrentLocation,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(NaviaSpacing.md),
              child: Text(
                AppStrings.searchAttribution,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.offerCurrentLocation});

  final bool offerCurrentLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchControllerProvider);
    final theme = Theme.of(context);

    final message = switch (state.status) {
      SearchStatus.idle => AppStrings.searchIdle,
      SearchStatus.empty => AppStrings.searchEmpty(state.query),
      SearchStatus.failed => state.failure?.message,
      SearchStatus.loading || SearchStatus.results => null,
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: NaviaSpacing.sm),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (offerCurrentLocation)
          ListTile(
            leading: const NaviaIconBadge(NaviaIcons.locateFixed),
            title: const Text(AppStrings.yourLocation),
            onTap: () => Navigator.of(context).pop(const CurrentLocationPick()),
          ),
        for (final place in state.results)
          _PlaceTile(
            place: place,
            onTap: () => Navigator.of(context).pop(PlacePick(place)),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.all(NaviaSpacing.xl),
            child: Column(
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (state.status == SearchStatus.failed &&
                    (state.failure?.isRetryable ?? false)) ...[
                  const SizedBox(height: NaviaSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: ref
                        .read(searchControllerProvider.notifier)
                        .retry,
                    icon: const NaviaIcon(NaviaIcons.refresh),
                    label: const Text(AppStrings.retry),
                  ),
                ],
                if (state.status == SearchStatus.idle) ...[
                  const SizedBox(height: NaviaSpacing.sm),
                  Text(
                    AppStrings.searchLongPressTip,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A search result: name, category and address, and coordinates.
class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.place, required this.onTap});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final details = [?place.category, ?place.description].join(' · ');

    return ListTile(
      leading: const NaviaIconBadge(NaviaIcons.destination),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (details.isNotEmpty)
            Text(
              details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            place.point.toDisplayString(),
            style: muted?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
