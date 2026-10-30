import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/utils/formatters.dart';

void main() {
  group('formatDistance', () {
    test('uses meters below one kilometer', () {
      expect(formatDistance(4), '4 m');
      expect(formatDistance(847), '850 m');
      expect(formatDistance(994), '990 m');
    });

    test('uses one decimal with a comma below ten kilometers', () {
      expect(formatDistance(1000), '1,0 km');
      expect(formatDistance(1670.8), '1,7 km');
    });

    test('rounds to whole kilometers above ten kilometers', () {
      expect(formatDistance(12449), '12 km');
      expect(formatDistance(250600), '251 km');
    });
  });

  group('formatDuration', () {
    test('shows short durations in minutes', () {
      expect(formatDuration(const Duration(seconds: 20)), '< 1 min');
      expect(formatDuration(const Duration(seconds: 181)), '3 min');
      expect(formatDuration(const Duration(minutes: 59)), '59 min');
    });

    test('shows hours with zero-padded minutes', () {
      expect(formatDuration(const Duration(minutes: 65)), '1 h 05 min');
      expect(formatDuration(const Duration(hours: 3)), '3 h');
    });
  });

  test('formatClockTime uses the 24-hour clock with padded minutes', () {
    expect(formatClockTime(DateTime(2026, 10, 30, 9, 5)), '9:05');
    expect(formatClockTime(DateTime(2026, 10, 30, 14, 32)), '14:32');
  });

  test('formatBytes uses kB below 1 MB and one decimal above', () {
    expect(formatBytes(850), '1 kB');
    expect(formatBytes(420000), '420 kB');
    expect(formatBytes(3041781), '3,0 MB');
  });

  test('formatCount and formatShortDate follow Italian conventions', () {
    expect(formatCount(7), '7');
    expect(formatCount(126088), '126.088');
    expect(formatCount(1234567), '1.234.567');
    expect(formatShortDate(DateTime(2026, 3, 5)), '05/03/2026');
  });
}
