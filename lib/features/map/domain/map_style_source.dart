import 'package:flutter/foundation.dart';

/// An attribution notice required by a map data or tile provider.
@immutable
class MapAttribution {
  const MapAttribution({required this.label, required this.url});

  final String label;
  final String url;
}

/// A provider of MapLibre style documents.
///
/// The renderer only receives a style URL, so swapping providers (or pointing
/// to a self-hosted tile server) is a configuration change.
@immutable
class MapStyleSource {
  const MapStyleSource({
    required this.name,
    required this.lightStyleUrl,
    required this.darkStyleUrl,
    required this.attributions,
  });

  /// Display name of the provider.
  final String name;

  final String lightStyleUrl;
  final String darkStyleUrl;

  /// Notices to display, in order. Map data notices must never be removed.
  final List<MapAttribution> attributions;

  String styleUrlFor(Brightness brightness) =>
      brightness == Brightness.dark ? darkStyleUrl : lightStyleUrl;
}
