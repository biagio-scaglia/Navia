import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/navia_icon.dart';
import '../../../core/widgets/navia_sheet.dart';
import '../domain/favorite.dart';
import 'favorites_controller.dart';

/// What the user chose in the favorites screen.
class FavoritePick {
  const FavoritePick(this.favorite, {this.directions = false});

  final Favorite favorite;

  /// True for a route to the favorite, false to show it on the map.
  final bool directions;
}

/// Saved places, available offline. Pops with a [FavoritePick].
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  static Future<FavoritePick?> open(BuildContext context) =>
      Navigator.of(context).push<FavoritePick>(
        MaterialPageRoute(builder: (_) => const FavoritesScreen()),
      );

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Favorite favorite,
  ) async {
    final name = await showNameDialog(
      context,
      title: AppStrings.renameFavorite,
      label: AppStrings.favoriteName,
      initialValue: favorite.name,
    );
    if (name != null) {
      await ref.read(favoritesProvider.notifier).rename(favorite.id, name);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Favorite favorite,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(favoritesProvider.notifier);
    final removed = await controller.remove(favorite.id);
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppStrings.favoriteDeleted(removed.name)),
          action: SnackBarAction(
            label: AppStrings.undo,
            onPressed: () => controller.restore(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: const Text(AppStrings.favorites),
      ),
      body: SafeArea(
        top: false,
        child: favorites.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(NaviaSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const NaviaIconBadge(NaviaIcons.star, size: 88),
                      const SizedBox(height: NaviaSpacing.lg),
                      Text(
                        AppStrings.favoritesEmptyTitle,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: NaviaSpacing.sm),
                      Text(
                        AppStrings.favoritesEmptyBody,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: NaviaSpacing.sm),
                itemCount: favorites.length,
                itemBuilder: (context, index) {
                  final favorite = favorites[index];
                  return ListTile(
                    leading: const NaviaIconBadge(NaviaIcons.starFilled),
                    title: Text(
                      favorite.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        ?favorite.category,
                        favorite.address ?? favorite.point.toDisplayString(),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () =>
                        Navigator.of(context).pop(FavoritePick(favorite)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: AppStrings.directions,
                          onPressed: () => Navigator.of(
                            context,
                          ).pop(FavoritePick(favorite, directions: true)),
                          icon: NaviaIcon(
                            NaviaIcons.directions,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        IconButton(
                          tooltip: AppStrings.rename,
                          onPressed: () => _rename(context, ref, favorite),
                          icon: const NaviaIcon(NaviaIcons.edit),
                        ),
                        IconButton(
                          tooltip: AppStrings.delete,
                          onPressed: () => _delete(context, ref, favorite),
                          icon: const NaviaIcon(NaviaIcons.trash),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
