import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

/// Renders the marker images: a colored disc with a white ring and the
/// category icon in white. Drawn once and registered with each map style.
abstract final class PlaceMarkerImages {
  /// Image size in pixels; the map scales it down for sharp markers.
  static const size = 96.0;

  static Future<Map<String, Uint8List>> render() async {
    final images = <String, Uint8List>{};
    for (final category in PoiCategory.values) {
      images[category.markerImageId] = await _marker(category);
    }
    return images;
  }

  static Future<Uint8List> _marker(PoiCategory category) async {
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
      ..drawCircle(center, radius - 6, Paint()..color = category.markerColor);

    final icon = await vg.loadPicture(
      SvgAssetLoader(category.icon.asset),
      null,
    );
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
