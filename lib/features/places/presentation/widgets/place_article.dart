import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/open_link.dart';
import '../../../../shared/models/geo_point.dart';
import '../../data/wikipedia_repository.dart';
import '../../domain/poi.dart';

/// The Wikipedia summary of a place: the article OpenStreetMap links, or
/// a nearby one with the same name.
///
/// Nothing is shown when no article is found, and failures are silent:
/// the rest of the card does not depend on Wikipedia.
class PlaceArticleSection extends ConsumerWidget {
  const PlaceArticleSection({
    super.key,
    this.place,
    this.name,
    required this.point,
  });

  final Poi? place;
  final String? name;
  final GeoPoint point;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (place: place, name: name, point: point);
    if (!hasArticleLookup(query)) return const SizedBox.shrink();
    final linked = place?.wikipedia != null || place?.wikidata != null;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ref
        .watch(placeArticleProvider(query))
        .when(
          // Most places have no article: only linked ones say it is coming.
          loading: () => !linked
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: NaviaSpacing.sm,
                  ),
                  child: Text(AppStrings.loadingWikipedia, style: muted),
                ),
          error: (_, _) => const SizedBox.shrink(),
          data: (article) {
            if (article == null) return const SizedBox.shrink();
            final thumbnail = article.thumbnail;
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (thumbnail != null) ...[
                            ClipRRect(
                              borderRadius: NaviaRadii.smAll,
                              child: Image.network(
                                thumbnail.toString(),
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                                semanticLabel: article.title,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(width: NaviaSpacing.md),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.fromWikipedia,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  article.extract,
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: NaviaSpacing.sm,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(
                                0,
                                NaviaSizes.minTouchTarget,
                              ),
                            ),
                            onPressed: () => openExternalLink(
                              context,
                              article.url.toString(),
                            ),
                            child: const Text(AppStrings.readOnWikipedia),
                          ),
                          Text(AppStrings.wikipediaLicense, style: muted),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
  }
}
