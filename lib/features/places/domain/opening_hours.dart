import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

enum OpeningStatus { open, closed }

/// A weekly schedule parsed from the OpenStreetMap `opening_hours` tag.
///
/// Only the common subset of the syntax is supported: weekday selectors
/// (`Mo-Fr`, `Sa,Su`), time ranges (`08:30-13:00,16:00-19:30`, overnight
/// ranges such as `20:00-02:00`), `off`/`closed` and `24/7`. Anything else,
/// such as public holidays (`PH`), months, week numbers, sunrise or
/// comments, makes [tryParse] return null: the status would otherwise be
/// wrong on some days, and Navia then shows the original text instead.
@immutable
class OpeningHours {
  const OpeningHours._(this._days);

  /// Open ranges for each weekday, Monday first, in minutes from midnight.
  /// An end beyond 1440 continues into the next day.
  final List<List<(int, int)>> _days;

  static const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  static OpeningHours? tryParse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (value == '24/7') {
      return OpeningHours._(List.filled(7, const [(0, 1440)]));
    }
    final days = List<List<(int, int)>>.generate(7, (_) => []);
    for (final rule in value.split(';')) {
      final trimmed = rule.trim();
      if (trimmed.isEmpty) continue;
      if (!_applyRule(trimmed, days)) return null;
    }
    return OpeningHours._(days);
  }

  /// Parses one rule and, as in the OSM specification, lets it replace the
  /// schedule of the days it names.
  static bool _applyRule(String rule, List<List<(int, int)>> days) {
    final match = RegExp(
      r'^((?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?'
      r'(?:,(?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?)*)?'
      r'\s*(.*)$',
    ).firstMatch(rule);
    if (match == null) return false;
    final selector = match.group(1);
    final rest = match.group(2)!.trim();

    final selected = selector == null
        ? List<int>.generate(7, (i) => i)
        : _selectedDays(selector);

    final List<(int, int)> ranges;
    if (rest == 'off' || rest == 'closed') {
      ranges = const [];
    } else {
      final parsed = _ranges(rest);
      if (parsed == null) return false;
      ranges = parsed;
    }
    for (final day in selected) {
      days[day] = ranges;
    }
    return true;
  }

  static List<int> _selectedDays(String selector) {
    final result = <int>{};
    for (final part in selector.split(',')) {
      final bounds = part.split('-').map(_dayNames.indexOf).toList();
      final start = bounds.first;
      final end = bounds.last;
      // Ranges such as Fr-Mo wrap around the week.
      for (var day = start; ; day = (day + 1) % 7) {
        result.add(day);
        if (day == end) break;
      }
    }
    return result.toList();
  }

  static List<(int, int)>? _ranges(String value) {
    final ranges = <(int, int)>[];
    for (final part in value.split(',')) {
      final match = RegExp(
        r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$',
      ).firstMatch(part.trim());
      if (match == null) return null;
      final values = [for (var i = 1; i <= 4; i++) int.parse(match.group(i)!)];
      final start = values[0] * 60 + values[1];
      var end = values[2] * 60 + values[3];
      if (values[1] > 59 || values[3] > 59 || start >= 1440 || end > 2880) {
        return null;
      }
      if (end <= start) end += 1440;
      if (end > start + 1440) return null;
      ranges.add((start, end));
    }
    return ranges;
  }

  /// Status at [localTime], the local time of the place.
  OpeningStatus statusAt(DateTime localTime) {
    final day = localTime.weekday - 1;
    final minute = localTime.hour * 60 + localTime.minute;
    final previous = (day + 6) % 7;
    final open =
        _days[day].any((r) => minute >= r.$1 && minute < r.$2) ||
        _days[previous].any((r) => r.$2 > 1440 && minute < r.$2 - 1440);
    return open ? OpeningStatus.open : OpeningStatus.closed;
  }

  /// Status of a place at [point] at the instant [now], or null when
  /// Navia cannot tell the local time there.
  ///
  /// Navia has no time zone database. It computes the local time only in
  /// the Central European Time area around Italy, whose rules it knows
  /// (UTC+1, UTC+2 from the last Sunday of March to the last Sunday of
  /// October); elsewhere the status is unknown.
  OpeningStatus? statusNear(GeoPoint point, DateTime now) {
    final local = centralEuropeanTime(point, now);
    return local == null ? null : statusAt(local);
  }

  /// Local time at [point], if it lies in the supported area.
  @visibleForTesting
  static DateTime? centralEuropeanTime(GeoPoint point, DateTime now) {
    final lat = point.latitude;
    final lng = point.longitude;
    final inArea = lat >= 35.2 && lat <= 47.2 && lng >= 6.5 && lng <= 18.6;
    // Excludes Tunisia and Algeria (no daylight saving time), south-west
    // of Sicily.
    final northAfrica = lat < 37.6 && lng < 11.8;
    if (!inArea || northAfrica) return null;

    final utc = now.toUtc();
    final summerStart = _lastSunday(utc.year, 3);
    final summerEnd = _lastSunday(utc.year, 10);
    final summer = !utc.isBefore(summerStart) && utc.isBefore(summerEnd);
    final local = utc.add(Duration(hours: summer ? 2 : 1));
    // Returned as a plain wall-clock value.
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  /// 01:00 UTC on the last Sunday of [month], when EU clocks change.
  static DateTime _lastSunday(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0);
    final sunday = lastDay.subtract(Duration(days: lastDay.weekday % 7));
    return DateTime.utc(year, month, sunday.day, 1);
  }
}
