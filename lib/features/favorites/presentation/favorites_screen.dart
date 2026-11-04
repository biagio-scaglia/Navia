import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/navia_tokens.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/navia_buttons.dart';
import '../../../core/widgets/navia_icon.dart';
import '../../../core/widgets/navia_sheet.dart';
import '../../places/presentation/place_marker_style.dart';
import '../domain/favorite.dart';
import 'favorites_controller.dart';

/// What the user chose in the favorites screen.
class FavoritePick {
  const FavoritePick(this.favorite, {this.directions = false});

  final Favorite favorite;

  /// True for a route to the favorite, false to show it on the map.
  final bool directions;
}

enum _FavoriteAction { rename, move, delete }

/// Saved places, available offline, optionally grouped in folders. Pops
/// with a [FavoritePick].
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  static Future<FavoritePick?> open(BuildContext context) =>
      Navigator.of(context).push<FavoritePick>(
        MaterialPageRoute(builder: (_) => const FavoritesScreen()),
      );

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  /// The folder shown, or null for all favorites.
  String? _folderId;

  FavoritesController get _favorites => ref.read(favoritesProvider.notifier);
  FavoriteFoldersController get _folders =>
      ref.read(favoriteFoldersProvider.notifier);

  Future<FavoriteFolder?> _createFolder() async {
    final name = await showNameDialog(
      context,
      title: AppStrings.newFolder,
      label: AppStrings.folderName,
    );
    if (name == null) return null;
    return _folders.create(name);
  }

  Future<void> _renameFolder(FavoriteFolder folder) async {
    final name = await showNameDialog(
      context,
      title: AppStrings.renameFolder,
      label: AppStrings.folderName,
      initialValue: folder.name,
    );
    if (name != null) await _folders.rename(folder.id, name);
  }

  Future<void> _deleteFolder(FavoriteFolder folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deleteFolderTitle(folder.name)),
        content: const Text(AppStrings.deleteFolderBody),
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
    if (confirmed != true) return;
    await _folders.delete(folder.id);
    if (mounted) setState(() => _folderId = null);
  }

  Future<void> _rename(Favorite favorite) async {
    final name = await showNameDialog(
      context,
      title: AppStrings.renameFavorite,
      label: AppStrings.favoriteName,
      initialValue: favorite.name,
    );
    if (name != null) await _favorites.rename(favorite.id, name);
  }

  Future<void> _move(Favorite favorite) async {
    final folders = ref.read(favoriteFoldersProvider);
    // An empty id stands for "new folder"; null for a dismissed dialog.
    final choice = await showDialog<({String? id})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text(AppStrings.moveToFolder),
        children: [
          _FolderOption(
            label: AppStrings.noFolder,
            color: FavoriteMarker.color,
            selected: favorite.folderId == null,
            onTap: () => Navigator.of(context).pop((id: null)),
          ),
          for (final folder in folders)
            _FolderOption(
              label: folder.name,
              color: FavoriteMarker.colorOf(folder.colorIndex),
              selected: favorite.folderId == folder.id,
              onTap: () => Navigator.of(context).pop((id: folder.id)),
            ),
          _FolderOption(
            label: AppStrings.newFolder,
            icon: NaviaIcons.plus,
            onTap: () => Navigator.of(context).pop((id: '')),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    var folderId = choice.id;
    String? folderName;
    if (folderId == '') {
      final created = await _createFolder();
      if (created == null) return;
      folderId = created.id;
      folderName = created.name;
    } else if (folderId != null) {
      folderName = folders.firstWhere((f) => f.id == folderId).name;
    }
    if (folderId == favorite.folderId) return;
    await _favorites.move(favorite.id, folderId);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.movedToFolder(
              favorite.name,
              folderName ?? AppStrings.noFolder,
            ),
          ),
        ),
      );
  }

  Future<void> _delete(Favorite favorite) async {
    final messenger = ScaffoldMessenger.of(context);
    final removed = await _favorites.remove(favorite.id);
    if (removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppStrings.favoriteDeleted(removed.name)),
          action: SnackBarAction(
            label: AppStrings.undo,
            onPressed: () => _favorites.restore(removed),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final folders = ref.watch(favoriteFoldersProvider);
    final folder = folders.where((f) => f.id == _folderId).firstOrNull;
    final shown = folder == null
        ? favorites
        : [
            for (final favorite in favorites)
              if (favorite.folderId == folder.id) favorite,
          ];
    final colors = {for (final f in folders) f.id: f.colorIndex};
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const NaviaBackButton(),
        title: Text(folder?.name ?? AppStrings.favorites),
        actions: [
          if (folder != null) ...[
            IconButton(
              tooltip: AppStrings.renameFolder,
              onPressed: () => _renameFolder(folder),
              icon: const NaviaIcon(NaviaIcons.edit),
            ),
            IconButton(
              tooltip: AppStrings.deleteFolder,
              onPressed: () => _deleteFolder(folder),
              icon: const NaviaIcon(NaviaIcons.trash),
            ),
          ],
        ],
      ),
      body: SafeArea(
        top: false,
        child: favorites.isEmpty && folders.isEmpty
            ? const _EmptyFavorites()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _FolderBar(
                    folders: folders,
                    favorites: favorites,
                    selected: folder?.id,
                    onSelected: (id) => setState(() => _folderId = id),
                    onCreate: () async {
                      final created = await _createFolder();
                      if (created != null && mounted) {
                        setState(() => _folderId = created.id);
                      }
                    },
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(NaviaSpacing.xxl),
                              child: Text(
                                folder == null
                                    ? AppStrings.favoritesEmptyBody
                                    : AppStrings.folderEmpty,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              vertical: NaviaSpacing.sm,
                            ),
                            itemCount: shown.length,
                            itemBuilder: (context, index) {
                              final favorite = shown[index];
                              return _FavoriteTile(
                                favorite: favorite,
                                color: FavoriteMarker.colorOf(
                                  colors[favorite.folderId],
                                ),
                                onAction: (action) => switch (action) {
                                  _FavoriteAction.rename => _rename(favorite),
                                  _FavoriteAction.move => _move(favorite),
                                  _FavoriteAction.delete => _delete(favorite),
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
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
    );
  }
}

/// "Tutti", one chip per folder with its color and count, and "Nuova
/// cartella", scrolling sideways.
class _FolderBar extends StatelessWidget {
  const _FolderBar({
    required this.folders,
    required this.favorites,
    required this.selected,
    required this.onSelected,
    required this.onCreate,
  });

  final List<FavoriteFolder> folders;
  final List<Favorite> favorites;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        NaviaSpacing.lg,
        NaviaSpacing.sm,
        NaviaSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('${AppStrings.allFavorites} · ${favorites.length}'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final folder in folders) ...[
            const SizedBox(width: NaviaSpacing.sm),
            ChoiceChip(
              avatar: NaviaIcon(
                NaviaIcons.folder,
                size: 18,
                color: FavoriteMarker.colorOf(folder.colorIndex),
              ),
              label: Text(
                '${folder.name} · '
                '${favorites.where((f) => f.folderId == folder.id).length}',
              ),
              selected: selected == folder.id,
              onSelected: (_) => onSelected(folder.id),
            ),
          ],
          const SizedBox(width: NaviaSpacing.sm),
          ActionChip(
            avatar: const NaviaIcon(NaviaIcons.plus, size: 18),
            label: const Text(AppStrings.newFolder),
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _FavoriteTile extends StatelessWidget {
  const _FavoriteTile({
    required this.favorite,
    required this.color,
    required this.onAction,
  });

  final Favorite favorite;

  /// Color of the favorite's folder, matching its pin on the map.
  final Color color;
  final ValueChanged<_FavoriteAction> onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: NaviaIconBadge(NaviaIcons.starFilled, color: color),
      title: Text(favorite.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          ?favorite.category,
          favorite.address ?? favorite.point.toDisplayString(),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => Navigator.of(context).pop(FavoritePick(favorite)),
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
          PopupMenuButton<_FavoriteAction>(
            tooltip: AppStrings.moreActions,
            icon: const NaviaIcon(NaviaIcons.more),
            onSelected: onAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _FavoriteAction.rename,
                child: _MenuRow(NaviaIcons.edit, AppStrings.rename),
              ),
              PopupMenuItem(
                value: _FavoriteAction.move,
                child: _MenuRow(NaviaIcons.folder, AppStrings.moveToFolder),
              ),
              PopupMenuItem(
                value: _FavoriteAction.delete,
                child: _MenuRow(NaviaIcons.trash, AppStrings.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final NaviaIcons icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox.square(dimension: 20, child: NaviaIcon(icon, size: 20)),
      const SizedBox(width: NaviaSpacing.md),
      Flexible(child: Text(label)),
    ],
  );
}

class _FolderOption extends StatelessWidget {
  const _FolderOption({
    required this.label,
    required this.onTap,
    this.color,
    this.icon = NaviaIcons.folder,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final NaviaIcons icon;
  final bool selected;

  @override
  Widget build(BuildContext context) => SimpleDialogOption(
    onPressed: onTap,
    child: Row(
      children: [
        SizedBox.square(
          dimension: 20,
          child: NaviaIcon(icon, size: 20, color: color),
        ),
        const SizedBox(width: NaviaSpacing.md),
        Expanded(child: Text(label)),
        if (selected)
          const SizedBox.square(
            dimension: 20,
            child: NaviaIcon(NaviaIcons.check, size: 20),
          ),
      ],
    ),
  );
}
