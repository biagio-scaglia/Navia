import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/navia_tokens.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/open_link.dart';
import '../../data/wikipedia_repository.dart';
import '../../domain/poi.dart';

/// The Wikipedia summary of a place, when OpenStreetMap links one.
///
/// Nothing is shown for places without a link, and failures are silent:
/// the rest of the card does not depend on Wikipedia.
class PlaceArticleSection extends ConsumerWidget {
  const PlaceArticleSection({super.key, required this.place});

  final Poi place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (place.wikipedia == null && place.wikidata == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ref
        .watch(placeArticleProvider(place))
        .when(
          loading: () => Padding(
            padding: const EdgeInsets.symmetric(vertical: NaviaSpacing.sm),
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
