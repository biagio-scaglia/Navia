import 'package:flutter/foundation.dart';

/// An attribution notice required by a map data or tile provider.
@immutable
class MapAttribution {
  const MapAttribution({required this.label, required this.url});

  final String label;
  final String url;
}

/// Concrete map styles Navia knows how to present.
enum MapStyleId {
  /// Detailed general-purpose map with POIs and 3D-ready buildings.
  standard,

  /// Higher-contrast, colorful variant.
  vivid,

  /// Low-detail light map that keeps attention on routes.
  minimal,

  /// Dark map for night use.
  dark;

  /// Whether the style is predominantly dark (for system bar contrast and
  /// overlay colors).
  bool get isDark => this == MapStyleId.dark;
}

/// What the user picked in the map appearance selector.
enum MapAppearance {
  /// Follows the app theme: [MapStyleId.standard] or [MapStyleId.dark].
  automatic,
  standard,
  vivid,
  minimal,
  dark;

  /// The style to load for this appearance in the given app [brightness].
  MapStyleId resolve(Brightness brightness) => switch (this) {
    MapAppearance.automatic =>
      brightness == Brightness.dark ? MapStyleId.dark : MapStyleId.standard,
    MapAppearance.standard => MapStyleId.standard,
    MapAppearance.vivid => MapStyleId.vivid,
    MapAppearance.minimal => MapStyleId.minimal,
    MapAppearance.dark => MapStyleId.dark,
  };

  static MapAppearance fromStorage(String? value) =>
      MapAppearance.values.firstWhere(
        (a) => a.name == value,
        orElse: () => MapAppearance.automatic,
      );
}

/// A provider of MapLibre style documents.
///
/// The renderer only receives a style URL, so swapping providers (or pointing
/// to a self-hosted tile server) is a configuration change.
@immutable
class MapStyleSource {
  const MapStyleSource({
    required this.name,
    required this.styleUrls,
    required this.attributions,
    this.buildingsSourceId,
    this.buildingsSourceLayer,
  });

  /// Display name of the provider.
  final String name;

  /// Style document URL for each supported style. Must contain
  /// [MapStyleId.standard].
  final Map<MapStyleId, String> styleUrls;

  /// Notices to display, in order. Map data notices must never be removed.
  final List<MapAttribution> attributions;

  /// Vector source and layer holding building footprints with real heights
  /// (`render_height`, `render_min_height` in the OpenMapTiles schema).
  /// Null when the provider has no height data: 3D buildings are then
  /// unavailable rather than faked.
  final String? buildingsSourceId;
  final String? buildingsSourceLayer;

  bool get supportsBuildings3d =>
      buildingsSourceId != null && buildingsSourceLayer != null;

  /// Styles this provider offers.
  Iterable<MapStyleId> get styles => styleUrls.keys;

  /// URL for [style], falling back to the standard style when the provider
  /// does not offer it.
  String urlFor(MapStyleId style) =>
      styleUrls[style] ?? styleUrls[MapStyleId.standard]!;

  /// Whether [appearance] can be shown with this provider.
  bool supports(MapAppearance appearance) => switch (appearance) {
    MapAppearance.automatic =>
      styleUrls.containsKey(MapStyleId.standard) &&
          styleUrls.containsKey(MapStyleId.dark),
    MapAppearance.standard => styleUrls.containsKey(MapStyleId.standard),
    MapAppearance.vivid => styleUrls.containsKey(MapStyleId.vivid),
    MapAppearance.minimal => styleUrls.containsKey(MapStyleId.minimal),
    MapAppearance.dark => styleUrls.containsKey(MapStyleId.dark),
  };
}
