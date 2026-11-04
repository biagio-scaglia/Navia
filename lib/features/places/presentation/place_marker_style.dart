import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/widgets/navia_icon.dart';
import '../domain/poi_category.dart';
import 'widgets/place_category_bar.dart';

/// Marker color and image of each discovery category.
extension PoiCategoryMarker on PoiCategory {
  /// Distinct, saturated colors that stay readable on light and dark maps.
  Color get markerColor => switch (this) {
    PoiCategory.restaurants => const Color(0xFFE8590C),
    PoiCategory.cafes => const Color(0xFF9C5B2E),
    PoiCategory.supermarkets => const Color(0xFFC2255C),
    PoiCategory.pharmacies => const Color(0xFF2B8A3E),
    PoiCategory.hospitals => const Color(0xFFE03131),
    PoiCategory.museums => const Color(0xFF7048E8),
    PoiCategory.attractions => const Color(0xFFE67700),
    PoiCategory.parks => const Color(0xFF5C940D),
    PoiCategory.hotels => const Color(0xFF1C7ED6),
    PoiCategory.transport => const Color(0xFF1864AB),
    PoiCategory.parking => const Color(0xFF364FC7),
    PoiCategory.fuel => const Color(0xFF495057),
    PoiCategory.atms => const Color(0xFF0C8599),
    PoiCategory.drinkingWater => const Color(0xFF1098AD),
    PoiCategory.toilets => const Color(0xFF5F3DC4),
    PoiCategory.beaches => const Color(0xFFF08C00),
  };

  /// Name of the marker image registered with the map style.
  String get markerImageId => 'navia-place-$name';
}

/// Markers of the places saved in the favorites: a star, gold outside any
/// folder and in the folder's color inside one.
abstract final class FavoriteMarker {
  static const color = Color(0xFFF2A900);
  static const imageId = 'navia-place-favorite';

  /// Folder colors, distinct from the gold star and readable on light and
  /// dark maps; a folder's color index picks one.
  static const folderColors = [
    Color(0xFFE64980),
    Color(0xFF12B886),
    Color(0xFF4C6EF5),
    Color(0xFFFD7E14),
    Color(0xFF7950F2),
    Color(0xFF15AABF),
  ];

  static Color colorOf(int? folderColor) => folderColor == null
      ? color
      : folderColors[folderColor % folderColors.length];

  static String imageOf(int? folderColor) => folderColor == null
      ? imageId
      : '$imageId-${folderColor % folderColors.length}';
}

/// AMTAB stops and lines on the map.
abstract final class TransitMarker {
  static const color = Color(0xFF1864AB);
  static const imageId = 'navia-place-bus-stop';

  /// The line's own color, or [color] when it is missing or too light to
  /// read on the map (AMTAB's line 01 is white).
  static Color lineColor(int? rgb) {
    if (rgb == null) return color;
    final line = Color(0xFF000000 | rgb);
    return line.computeLuminance() > 0.7 ? color : line;
  }
}

/// Renders the marker images: a colored disc with a white ring and the
/// category icon in white. Drawn once and registered with each map style.
abstract final class PlaceMarkerImages {
  /// Image size in pixels; the map scales it down for sharp markers.
  static const size = 96.0;

  static Future<Map<String, Uint8List>> render() async {
    final images = <String, Uint8List>{};
    for (final category in PoiCategory.values) {
      images[category.markerImageId] = await _marker(
        category.markerColor,
        category.icon,
      );
    }
    images[TransitMarker.imageId] = await _marker(
      TransitMarker.color,
      NaviaIcons.bus,
    );
    for (final folderColor in <int?>[
      null,
      for (var i = 0; i < FavoriteMarker.folderColors.length; i++) i,
    ]) {
      images[FavoriteMarker.imageOf(folderColor)] = await _marker(
        FavoriteMarker.colorOf(folderColor),
        NaviaIcons.starFilled,
      );
    }
    return images;
  }

  static Future<Uint8List> _marker(Color color, NaviaIcons glyph) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    const radius = size / 2 - 6;

    canvas
      ..drawCircle(
        center.translate(0, 3),
        radius,
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      )
      ..drawCircle(center, radius, Paint()..color = Colors.white)
      ..drawCircle(center, radius - 6, Paint()..color = color);

    final icon = await vg.loadPicture(SvgAssetLoader(glyph.asset), null);
    const iconSize = size * 0.46;
    final scale = iconSize / icon.size.longestSide;
    canvas
      ..save()
      ..translate((size - iconSize) / 2, (size - iconSize) / 2)
      ..scale(scale)
      ..saveLayer(
        Offset.zero & icon.size,
        Paint()
          ..colorFilter = const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      )
      ..drawPicture(icon.picture)
      ..restore()
      ..restore();
    icon.picture.dispose();

    final image = await recorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }
}

/// Marker images, rendered once per app session.
final placeMarkerImagesProvider = FutureProvider<Map<String, Uint8List>>(
  (ref) => PlaceMarkerImages.render(),
);
