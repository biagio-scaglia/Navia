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
    required this.buildings,
  });

  final Color route;
  final Color routeCasing;
  final Color origin;
  final Color destination;
  final Color selection;
  final Color markerStroke;

  /// Color of extruded buildings in the 3D view.
  final Color buildings;
}

/// A named point of interest rendered by the map style.
@immutable
class MapPoi {
  const MapPoi({required this.name, required this.point, this.category});

  final String name;
  final GeoPoint point;

  /// Italian category label, when the feature class is known.
  final String? category;
}
