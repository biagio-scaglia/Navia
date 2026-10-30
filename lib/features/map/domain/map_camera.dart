import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// Renderer-independent camera position.
@immutable
class MapCamera {
  const MapCamera({
    required this.target,
    required this.zoom,
    this.bearing = 0,
    this.tilt = 0,
  });

  final GeoPoint target;

  /// Web Mercator zoom level (0 shows the whole world).
  final double zoom;

  /// Rotation in degrees clockwise from north.
  final double bearing;

  /// Camera pitch in degrees.
  final double tilt;
}
