import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../shared/models/geo_point.dart';

enum MapMarkerKind { origin, destination, selection }

/// A point drawn on top of the map.
@immutable
class MapMarker {
  const MapMarker(this.point, this.kind);

  final GeoPoint point;
  final MapMarkerKind kind;

  @override
  bool operator ==(Object other) =>
      other is MapMarker && other.point == point && other.kind == kind;

  @override
  int get hashCode => Object.hash(point, kind);
}

/// Colors of the overlays drawn by Navia, derived from the active theme.
@immutable
class MapOverlayStyle {
  const MapOverlayStyle({
    required this.route,
    required this.routeCasing,
    required this.origin,
    required this.destination,
    required this.selection,
    required this.markerStroke,
  });

  final Color route;
  final Color routeCasing;
  final Color origin;
  final Color destination;
  final Color selection;
  final Color markerStroke;
}
