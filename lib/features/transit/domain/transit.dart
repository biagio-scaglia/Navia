import 'package:flutter/foundation.dart';

import '../../../shared/models/geo_point.dart';

/// A bus stop of the downloaded timetables.
@immutable
class TransitStop {
  const TransitStop({
    required this.index,
    required this.id,
    required this.name,
    required this.point,
  });

  /// Position in the stored stop list, which names its departures file.
  final int index;

  /// GTFS `stop_id`.
  final String id;
  final String name;
  final GeoPoint point;
}

/// One scheduled departure from a stop.
@immutable
class Departure {
  const Departure({
    required this.time,
    required this.route,
    required this.headsign,
    this.color,
  });

  final DateTime time;

  /// Line number, e.g. "02/".
  final String route;

  /// Where the bus is going, as shown on its front.
  final String headsign;

  /// Line color as RGB, when the timetables give one.
  final int? color;

  @override
  bool operator ==(Object other) =>
      other is Departure &&
      other.time == time &&
      other.route == route &&
      other.headsign == headsign &&
      other.color == color;

  @override
  int get hashCode => Object.hash(time, route, headsign, color);
}

/// The days a GTFS service runs, from `calendar.txt` and
/// `calendar_dates.txt`. Days are `yyyymmdd` integers.
@immutable
class ServiceDays {
  const ServiceDays({
    this.start = 0,
    this.end = 0,
    this.weekdays = 0,
    this.added = const {},
    this.removed = const {},
  });

  final int start;
  final int end;

  /// Bit 0 is Monday, bit 6 Sunday.
  final int weekdays;
  final Set<int> added;
  final Set<int> removed;

  static int dayOf(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  bool runsOn(DateTime date) {
    final day = dayOf(date);
    if (removed.contains(day)) return false;
    if (added.contains(day)) return true;
    return day >= start &&
        day <= end &&
        weekdays & (1 << (date.weekday - 1)) != 0;
  }

  List<Object> toJson() => [
    start,
    end,
    weekdays,
    added.toList(),
    removed.toList(),
  ];

  static ServiceDays? tryParse(Object? json) {
    if (json is! List || json.length != 5) return null;
    final [start, end, weekdays, added, removed] = json;
    if (start is! int || end is! int || weekdays is! int) return null;
    if (added is! List || removed is! List) return null;
    return ServiceDays(
      start: start,
      end: end,
      weekdays: weekdays,
      added: {...added.whereType<int>()},
      removed: {...removed.whereType<int>()},
    );
  }
}

/// The installed timetables.
@immutable
class TransitInfo {
  const TransitInfo({
    required this.downloaded,
    required this.validFrom,
    required this.validUntil,
    required this.bytes,
    required this.stops,
  });

  final DateTime downloaded;

  /// First and last day covered by the timetables.
  final DateTime validFrom;
  final DateTime validUntil;

  /// Space used on the device.
  final int bytes;
  final int stops;

  bool expiredOn(DateTime now) =>
      DateTime(now.year, now.month, now.day).isAfter(validUntil);

  Map<String, Object> toJson() => {
    'downloaded': downloaded.toUtc().toIso8601String(),
    'validFrom': validFrom.toIso8601String().substring(0, 10),
    'validUntil': validUntil.toIso8601String().substring(0, 10),
    'bytes': bytes,
    'stops': stops,
  };

  static TransitInfo? tryParse(Object? json) {
    if (json is! Map) return null;
    final downloaded = DateTime.tryParse('${json['downloaded']}');
    final from = DateTime.tryParse('${json['validFrom']}');
    final until = DateTime.tryParse('${json['validUntil']}');
    final bytes = json['bytes'];
    final stops = json['stops'];
    if (downloaded == null ||
        from == null ||
        until == null ||
        bytes is! int ||
        stops is! int) {
      return null;
    }
    return TransitInfo(
      downloaded: downloaded,
      validFrom: from,
      validUntil: until,
      bytes: bytes,
      stops: stops,
    );
  }
}
