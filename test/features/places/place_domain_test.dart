import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/places/domain/place_links.dart';
import 'package:navia/features/places/domain/poi.dart';
import 'package:navia/features/places/domain/poi_category.dart';
import 'package:navia/shared/models/geo_point.dart';

void main() {
  group('OsmRef', () {
    test('round-trips its key and links to openstreetmap.org', () {
      const ref = OsmRef(OsmElementType.way, 42);
      expect(OsmRef.tryParse(ref.key), ref);
      expect(ref.url.toString(), 'https://www.openstreetmap.org/way/42');
    });

    test('rejects malformed keys', () {
      for (final key in ['', 'node', 'shop/1', 'node/x', 'node/-3', 7]) {
        expect(OsmRef.tryParse(key), isNull, reason: '$key');
      }
    });
  });

  test('categories match their OpenStreetMap tags', () {
    expect(PoiCategory.pharmacies.matches({'amenity': 'pharmacy'}), isTrue);
    expect(PoiCategory.transport.matches({'railway': 'station'}), isTrue);
    expect(PoiCategory.restaurants.matches({'amenity': 'pharmacy'}), isFalse);
    expect(PoiCategory.supermarkets.matches({}), isFalse);
  });

  group('PlaceLinks.website', () {
    test('accepts http(s) links and adds a missing scheme', () {
      expect(
        PlaceLinks.website('https://www.example.it/menu').toString(),
        'https://www.example.it/menu',
      );
      expect(PlaceLinks.website('example.it').toString(), 'https://example.it');
      expect(
        PlaceLinks.website('https://a.it;https://b.it').toString(),
        'https://a.it',
      );
    });

    test('rejects other schemes and malformed values', () {
      for (final value in [
        null,
        '',
        'javascript:alert(1)',
        'ftp://example.it',
        'not a site',
        'localhost',
        'mailto:info@example.it',
      ]) {
        expect(PlaceLinks.website(value), isNull, reason: '$value');
      }
    });
  });

  group('PlaceLinks.phone', () {
    test('keeps the first plausible number in readable form', () {
      expect(PlaceLinks.phone('+39 080 123-4567'), '+39 080 123 4567');
      expect(PlaceLinks.phone('080 5212345; +39 333 1234567'), '080 5212345');
      expect(
        PlaceLinks.phoneUri('+39 080 5212345').toString(),
        'tel:+390805212345',
      );
    });

    test('rejects values that are not phone numbers', () {
      for (final value in [
        null,
        '',
        'call us',
        '12',
        '+39 080 abc',
        '1' * 20,
      ]) {
        expect(PlaceLinks.phone(value), isNull, reason: '$value');
      }
    });
  });

  test('share text lists name, address, coordinates and a map link', () {
    final text = PlaceLinks.shareText(
      point: const GeoPoint(latitude: 41.12356, longitude: 16.87316),
      name: 'Teatro Petruzzelli',
      address: 'Corso Cavour, 12 · Bari',
    );
    expect(
      text,
      'Teatro Petruzzelli\n'
      'Corso Cavour, 12 · Bari\n'
      '41.12356, 16.87316\n'
      'https://www.openstreetmap.org/?mlat=41.12356&mlon=16.87316'
      '#map=18/41.12356/16.87316',
    );
    expect(
      PlaceLinks.shareText(
        point: const GeoPoint(latitude: 41.1, longitude: 16.8),
      ).split('\n'),
      hasLength(2),
    );
  });
}
