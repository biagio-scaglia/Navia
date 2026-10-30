import 'package:flutter_test/flutter_test.dart';
import 'package:navia/shared/models/geo_bounds.dart';
import 'package:navia/shared/models/geo_point.dart';

GeoBounds _bounds(double s, double w, double n, double e) =>
    GeoBounds.tryCreate(south: s, west: w, north: n, east: e)!;

void main() {
  test('rejects inverted, out of range and non-finite bounds', () {
    expect(GeoBounds.tryCreate(south: 2, west: 0, north: 1, east: 1), isNull);
    expect(GeoBounds.tryCreate(south: 0, west: 0, north: 91, east: 1), isNull);
    expect(
      GeoBounds.tryCreate(south: 0, west: 0, north: double.nan, east: 1),
      isNull,
    );
  });

  test('checks containment of points and bounds', () {
    final bari = _bounds(41.10, 16.85, 41.14, 16.90);
    expect(
      bari.containsPoint(const GeoPoint(latitude: 41.12, longitude: 16.87)),
      isTrue,
    );
    expect(bari.containsBounds(_bounds(41.11, 16.86, 41.13, 16.89)), isTrue);
    expect(bari.containsBounds(_bounds(41.11, 16.86, 41.15, 16.89)), isFalse);
  });

  test('expands each side by a fraction of the span', () {
    final expanded = _bounds(41.10, 16.80, 41.20, 16.90).expandedBy(0.5);
    expect(expanded.south, closeTo(41.05, 1e-9));
    expect(expanded.north, closeTo(41.25, 1e-9));
    expect(expanded.west, closeTo(16.75, 1e-9));
    expect(expanded.east, closeTo(16.95, 1e-9));
  });

  test('snaps outwards so that nearby views share the same bounds', () {
    final view = _bounds(41.1112, 16.8611, 41.1288, 16.8789);
    final a = view.snappedTo(0.02);
    final b = _bounds(41.1105, 16.8650, 41.1250, 16.8770).snappedTo(0.02);
    expect(a, b);
    expect(a.containsBounds(view), isTrue);
  });
}
