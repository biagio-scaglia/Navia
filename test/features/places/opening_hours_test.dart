import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/places/domain/opening_hours.dart';
import 'package:navia/shared/models/geo_point.dart';

// 2026-11-02 is a Monday.
DateTime _at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

const _bari = GeoPoint(latitude: 41.1171, longitude: 16.8719);

void main() {
  test('reads weekday ranges, split hours and closed days', () {
    final hours = OpeningHours.tryParse(
      'Mo-Fr 08:30-13:00,16:00-19:30; Sa 09:00-13:00; Su off',
    )!;
    expect(hours.statusAt(_at(2, 9)), OpeningStatus.open);
    expect(hours.statusAt(_at(2, 14)), OpeningStatus.closed);
    expect(hours.statusAt(_at(2, 19, 29)), OpeningStatus.open);
    expect(hours.statusAt(_at(2, 19, 30)), OpeningStatus.closed);
    expect(hours.statusAt(_at(7, 12)), OpeningStatus.open);
    expect(hours.statusAt(_at(8, 10)), OpeningStatus.closed);
  });

  test('later rules replace earlier ones for the days they name', () {
    final hours = OpeningHours.tryParse('Mo-Su 10:00-20:00; We off')!;
    expect(hours.statusAt(_at(4, 12)), OpeningStatus.closed);
    expect(hours.statusAt(_at(5, 12)), OpeningStatus.open);
  });

  test('handles overnight ranges, wrapping day ranges and 24/7', () {
    final bar = OpeningHours.tryParse('Fr-Mo 20:00-02:00')!;
    expect(bar.statusAt(_at(6, 23)), OpeningStatus.open);
    // Monday night continues into Tuesday 01:00.
    expect(bar.statusAt(_at(3, 1)), OpeningStatus.open);
    expect(bar.statusAt(_at(4, 1)), OpeningStatus.closed);
    expect(
      OpeningHours.tryParse('24/7')!.statusAt(_at(4, 3)),
      OpeningStatus.open,
    );
  });

  test('refuses syntax it cannot evaluate reliably', () {
    for (final value in [
      null,
      '',
      'Mo-Fr 08:00-18:00; PH off',
      'Jan-Mar 09:00-17:00',
      'Mo-Fr 08:00-12:00 "su appuntamento"',
      'Mo-Fr sunrise-sunset',
      'Mo-Fr 08:00-18:00 || "chiamare"',
      'Mo-Fr',
      'Mo-Fr 25:00-26:00',
      'Mo-Fr 08:00-18:00+',
    ]) {
      expect(OpeningHours.tryParse(value), isNull, reason: '$value');
    }
  });

  group('local time', () {
    test('applies Central European Time with EU daylight saving', () {
      // Winter: UTC+1.
      expect(
        OpeningHours.centralEuropeanTime(_bari, DateTime.utc(2026, 1, 15, 8)),
        DateTime(2026, 1, 15, 9),
      );
      // Summer time starts on 29 March 2026 at 01:00 UTC.
      expect(
        OpeningHours.centralEuropeanTime(
          _bari,
          DateTime.utc(2026, 3, 29, 0, 59),
        ),
        DateTime(2026, 3, 29, 1, 59),
      );
      expect(
        OpeningHours.centralEuropeanTime(_bari, DateTime.utc(2026, 3, 29, 1)),
        DateTime(2026, 3, 29, 3),
      );
      // It ends on 25 October 2026 at 01:00 UTC.
      expect(
        OpeningHours.centralEuropeanTime(_bari, DateTime.utc(2026, 10, 25, 1)),
        DateTime(2026, 10, 25, 2),
      );
    });

    test('is unknown outside the supported area', () {
      const tunis = GeoPoint(latitude: 36.8, longitude: 10.18);
      const london = GeoPoint(latitude: 51.5, longitude: -0.12);
      final now = DateTime.utc(2026, 6, 1, 12);
      expect(OpeningHours.centralEuropeanTime(tunis, now), isNull);
      expect(OpeningHours.centralEuropeanTime(london, now), isNull);
      expect(OpeningHours.tryParse('24/7')!.statusNear(london, now), isNull);
    });
  });
}
