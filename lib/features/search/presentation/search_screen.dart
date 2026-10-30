import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
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
        titleSpacing: 0,
        title: TextField(
          controller: _textController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: theme.textTheme.titleMedium,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: InputBorder.none,
          ),
          onChanged: ref.read(searchControllerProvider.notifier).updateQuery,
        ),
        actions: [
          ListenableBuilder(
            listenable: _textController,
            builder: (context, _) => _textController.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: AppStrings.clearSearch,
                    onPressed: _clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ],
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
            leading: Icon(
              Icons.my_location_rounded,
              color: theme.colorScheme.primary,
            ),
            title: const Text(AppStrings.yourLocation),
            onTap: () => Navigator.of(context).pop(const CurrentLocationPick()),
          ),
        for (final place in state.results)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(
              place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: place.description == null
                ? null
                : Text(
                    place.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                    icon: const Icon(Icons.refresh_rounded),
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
