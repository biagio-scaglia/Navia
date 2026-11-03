import 'dart:convert';

import '../domain/map_region.dart';

/// Turns a bundled style document into one that draws downloaded maps only.
///
/// The online vector source is replaced by the PMTiles archives of the
/// installed regions. With more than one region, every layer of that source
/// is repeated for each of them, next to each other, so the drawing order is
/// kept: the water of all regions comes before their roads, and so on. The
/// first region keeps the original source and layer ids, so the style's own
/// 3D buildings and Navia's extrusion layer keep working there. Other
/// sources (online raster relief) are removed with their layers, and fonts
/// and icons come from the app's assets, so nothing is requested from the
/// network.
abstract final class OfflineMapStyle {
  /// Where `tool/maps/fetch_offline_resources.py` puts fonts and icons, as
  /// MapLibre reads Flutter assets on Android.
  static const resources = 'asset://flutter_assets/assets/map_offline';

  static String build(
    Map<String, Object?> template, {
    required String sourceId,
    required List<InstalledMapRegion> regions,
  }) {
    final style = _copy(template);
    final sources = <String, Object?>{
      for (final (index, installed) in regions.indexed)
        _sourceId(sourceId, installed, index): {
          'type': 'vector',
          'url': 'pmtiles://file://${installed.tilesPath}',
        },
    };
    final layers = <Object?>[];
    for (final layer in (style['layers'] as List?) ?? const []) {
      if (layer is! Map<String, Object?>) continue;
      _renameFonts(layer);
      final source = layer['source'];
      if (source == null) {
        layers.add(layer);
      } else if (source == sourceId) {
        for (final (index, installed) in regions.indexed) {
          layers.add(
            index == 0
                ? layer
                : (_copy(layer)
                    ..['id'] = '${layer['id']}-${installed.region.id}'
                    ..['source'] = _sourceId(sourceId, installed, index)),
          );
        }
      }
    }
    style
      ..['sources'] = sources
      ..['layers'] = layers
      ..['glyphs'] = '$resources/fonts/{fontstack}/{range}.pbf'
      ..['sprite'] = '$resources/sprites/ofm';
    return jsonEncode(style);
  }

  /// Font folder of [font] in the assets: "Noto Sans Regular" is stored as
  /// "noto-sans-regular", so no URL encoding is involved.
  static String fontFolder(String font) =>
      font.toLowerCase().replaceAll(' ', '-');

  static String _sourceId(
    String sourceId,
    InstalledMapRegion installed,
    int index,
  ) => index == 0 ? sourceId : '$sourceId-${installed.region.id}';

  static void _renameFonts(Map<String, Object?> layer) {
    final layout = layer['layout'];
    if (layout is! Map<String, Object?>) return;
    final fonts = layout['text-font'];
    // Font expressions are left as they are; the bundled styles use lists.
    if (fonts is List && fonts.every((font) => font is String)) {
      layout['text-font'] = [
        for (final font in fonts) fontFolder(font as String),
      ];
    }
  }

  static Map<String, Object?> _copy(Map<String, Object?> json) =>
      jsonDecode(jsonEncode(json)) as Map<String, Object?>;
}
