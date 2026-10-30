import 'package:flutter_test/flutter_test.dart';
import 'package:navia/shared/models/geo_point.dart';

void main() {
  group('GeoPoint.tryCreate', () {
    test('accepts valid coordinates', () {
      expect(
        GeoPoint.tryCreate(41.1171, 16.8719),
        const GeoPoint(latitude: 41.1171, longitude: 16.8719),
      );
      expect(GeoPoint.tryCreate(-90, 180), isNotNull);
    });

    test('rejects out of range, non-finite and missing values', () {
      expect(GeoPoint.tryCreate(90.0001, 0), isNull);
      expect(GeoPoint.tryCreate(0, -180.5), isNull);
      expect(GeoPoint.tryCreate(double.nan, 0), isNull);
      expect(GeoPoint.tryCreate(0, double.infinity), isNull);
      expect(GeoPoint.tryCreate(null, 0), isNull);
    });
  });

  group('GeoPoint.tryParseLngLat', () {
    test('reads GeoJSON longitude-first order', () {
      expect(
        GeoPoint.tryParseLngLat([16.8719, 41.1171, 12.0]),
        const GeoPoint(latitude: 41.1171, longitude: 16.8719),
      );
    });

    test('rejects malformed positions', () {
      expect(GeoPoint.tryParseLngLat(null), isNull);
      expect(GeoPoint.tryParseLngLat([16.8]), isNull);
      expect(GeoPoint.tryParseLngLat(['16.8', 41.1]), isNull);
      expect(GeoPoint.tryParseLngLat([200, 41.1]), isNull);
    });
  });

  test('serializes and displays consistently', () {
    const point = GeoPoint(latitude: 41.1171, longitude: 16.8719);
    expect(point.toLngLat(), [16.8719, 41.1171]);
    expect(point.toDisplayString(), '41.11710, 16.87190');
  });
}
