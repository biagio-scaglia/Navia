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
    required this.place,
    required this.placeLabel,
    required this.placeLabelHalo,
  });

  final Color route;
  final Color routeCasing;
  final Color origin;
  final Color destination;
  final Color selection;
  final Color markerStroke;

  /// Color of extruded buildings in the 3D view.
  final Color buildings;

  /// Discovered places and their name labels.
  final Color place;
  final Color placeLabel;
  final Color placeLabelHalo;
}

/// An area drawn as a translucent fill, such as the places reachable in a
/// given time. [level] 0 is the nearest band.
@immutable
class MapArea {
  const MapArea({required this.level, required this.rings});

  final int level;

  /// Closed rings of `[longitude, latitude]` positions.
  final List<List<List<double>>> rings;
}

/// A discovered place drawn by Navia, identified by a stable [key].
@immutable
class MapPlace {
  const MapPlace({
    required this.key,
    required this.point,
    required this.imageId,
    required this.color,
    this.name,
    this.selected = false,
  });

  final String key;
  final GeoPoint point;

  /// Marker image registered with [NaviaMapController.setPlaceImages].
  final String imageId;

  /// Category color, used by the 3D column under the marker.
  final Color color;

  /// Label drawn next to the place; unnamed places get no label.
  final String? name;
  final bool selected;

  @override
  bool operator ==(Object other) =>
      other is MapPlace &&
      other.key == key &&
      other.point == point &&
      other.imageId == imageId &&
      other.color == color &&
      other.name == name &&
      other.selected == selected;

  @override
  int get hashCode => Object.hash(key, point, imageId, color, name, selected);
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
