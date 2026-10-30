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
}
