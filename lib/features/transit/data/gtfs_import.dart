import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import '../domain/transit.dart';
import 'zip_reader.dart';

/// Rows of a CSV text (RFC 4180: quoted fields may hold commas, quotes and
/// line breaks), header included.
Iterable<List<String>> csvRows(String text) sync* {
  var fields = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var i = 0;
  final n = text.length;
  while (i < n) {
    final c = text.codeUnitAt(i);
    if (quoted) {
      if (c == 0x22) {
        if (i + 1 < n && text.codeUnitAt(i + 1) == 0x22) {
          field.writeCharCode(0x22);
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        field.writeCharCode(c);
      }
      i++;
      continue;
    }
    if (c == 0x22) {
      quoted = true;
    } else if (c == 0x2C) {
      fields.add(field.toString());
      field.clear();
    } else if (c == 0x0A || c == 0x0D) {
      if (c == 0x0D && i + 1 < n && text.codeUnitAt(i + 1) == 0x0A) i++;
      fields.add(field.toString());
      field.clear();
      if (fields.length > 1 || fields.first.isNotEmpty) yield fields;
      fields = <String>[];
    } else {
      field.writeCharCode(c);
    }
    i++;
  }
  if (field.isNotEmpty || fields.isNotEmpty) {
    fields.add(field.toString());
    yield fields;
  }
}

/// A GTFS table: named columns over [csvRows].
class _Table {
  _Table(String text) : _rows = csvRows(text).iterator {
    if (_rows.moveNext()) {
      for (final (i, name) in _rows.current.indexed) {
        _columns[name.trim()] = i;
      }
    }
  }

  final Iterator<List<String>> _rows;
  final _columns = <String, int>{};

  bool has(String column) => _columns.containsKey(column);

  /// Each row as a lookup by column name; missing values are empty.
  Iterable<String Function(String)> get rows sync* {
    while (_rows.moveNext()) {
      final row = _rows.current;
      yield (column) {
        final i = _columns[column];
        return i == null || i >= row.length ? '' : row[i].trim();
      };
    }
  }
}

/// What an import produced.
class GtfsImportResult {
  const GtfsImportResult({
    required this.validFrom,
    required this.validUntil,
    required this.stops,
  });

  final DateTime validFrom;
  final DateTime validUntil;
  final int stops;
}

/// Turns a GTFS feed into the small files read by the app:
///
/// - `stops.json`: `[id, name, lat, lon, [route indexes]]` per stop;
/// - `routes.json`: `[short name, long name, color or null]` per route;
/// - `services.json`: the [ServiceDays] of each service;
/// - `stops/<i>.json`: departures from stop `i`, as
///   `[seconds after midnight, route, headsign, service]`, sorted;
/// - `routes/<i>.json`: route `i` with its shapes (`[[lat, lon], …]`) and
///   trips, as `[service, shape, headsign, [seconds], [meters along the
///   shape]]`, one value per stop.
///
/// Times past midnight stay above 86400, as in GTFS.
abstract final class GtfsImport {
  static GtfsImportResult build(ZipReader zip, Directory out) {
    String table(String name) {
      final text = zip.readText(name);
      if (text == null) throw FormatException('Missing $name');
      return text;
    }

    // Stops: only boarding points (location_type empty or 0).
    final stopIndex = <String, int>{};
    final stops = <List<Object>>[];
    for (final row in _Table(table('stops.txt')).rows) {
      final type = row('location_type');
      if (type.isNotEmpty && type != '0') continue;
      final lat = double.tryParse(row('stop_lat'));
      final lon = double.tryParse(row('stop_lon'));
      final id = row('stop_id');
      if (lat == null || lon == null || id.isEmpty) continue;
      stopIndex[id] = stops.length;
      stops.add([id, row('stop_name'), _round(lat), _round(lon)]);
    }
    if (stops.isEmpty) throw const FormatException('No stops');

    final routeIndex = <String, int>{};
    final routes = <List<Object?>>[];
    for (final row in _Table(table('routes.txt')).rows) {
      final id = row('route_id');
      if (id.isEmpty) continue;
      routeIndex[id] = routes.length;
      final short = row('route_short_name');
      routes.add([
        short.isEmpty ? row('route_long_name') : short,
        row('route_long_name'),
        int.tryParse(row('route_color'), radix: 16),
      ]);
    }

    // Services, from the weekly calendar and its exceptions.
    final services = <String, _ServiceBuilder>{};
    final calendar = zip.readText('calendar.txt');
    if (calendar != null) {
      const days = [
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
        'saturday',
        'sunday',
      ];
      for (final row in _Table(calendar).rows) {
        final service = services.putIfAbsent(
          row('service_id'),
          _ServiceBuilder.new,
        );
        service
          ..start = int.tryParse(row('start_date')) ?? 0
          ..end = int.tryParse(row('end_date')) ?? 0;
        for (final (bit, day) in days.indexed) {
          if (row(day) == '1') service.weekdays |= 1 << bit;
        }
      }
    }
    final calendarDates = zip.readText('calendar_dates.txt');
    if (calendarDates != null) {
      for (final row in _Table(calendarDates).rows) {
        final day = int.tryParse(row('date'));
        if (day == null) continue;
        final service = services.putIfAbsent(
          row('service_id'),
          _ServiceBuilder.new,
        );
        (row('exception_type') == '2' ? service.removed : service.added).add(
          day,
        );
      }
    }
    final serviceIds = services.keys.toList();
    final serviceIndex = {for (final (i, id) in serviceIds.indexed) id: i};

    final trips = <String, _Trip>{};
    for (final row in _Table(table('trips.txt')).rows) {
      final route = routeIndex[row('route_id')];
      final service = serviceIndex[row('service_id')];
      if (route == null || service == null) continue;
      trips[row('trip_id')] = _Trip(
        route,
        service,
        row('trip_headsign'),
        row('shape_id'),
      );
    }

    final shapePoints = <String, List<(int, double, double)>>{};
    final shapesText = zip.readText('shapes.txt');
    if (shapesText != null) {
      for (final row in _Table(shapesText).rows) {
        final seq = int.tryParse(row('shape_pt_sequence'));
        final lat = double.tryParse(row('shape_pt_lat'));
        final lon = double.tryParse(row('shape_pt_lon'));
        if (seq == null || lat == null || lon == null) continue;
        shapePoints.putIfAbsent(row('shape_id'), () => []).add((seq, lat, lon));
      }
    }

    for (final row in _Table(table('stop_times.txt')).rows) {
      final trip = trips[row('trip_id')];
      final stop = stopIndex[row('stop_id')];
      final seq = int.tryParse(row('stop_sequence'));
      final time =
          _seconds(row('departure_time')) ?? _seconds(row('arrival_time'));
      if (trip == null || stop == null || seq == null || time == null) {
        continue;
      }
      trip.calls.add((seq, time, stop));
    }

    // Per route: shapes as polylines, and trips with distances along them.
    final routeShapes = List.generate(routes.length, (_) => <String, int>{});
    final routeShapeLines = List.generate(
      routes.length,
      (_) => <List<List<double>>>[],
    );
    final routeTrips = List.generate(routes.length, (_) => <List<Object>>[]);
    final stopDepartures = List.generate(stops.length, (_) => <List<Object>>[]);
    final stopRoutes = List.generate(stops.length, (_) => <int>{});
    final projections = <String, List<int>>{};
    var firstDay = 99999999, lastDay = 0;

    for (final trip in trips.values) {
      if (trip.calls.length < 2) continue;
      trip.calls.sort((a, b) => a.$1.compareTo(b.$1));
      final calls = trip.calls;
      final stopIds = [for (final c in calls) c.$3];

      // The trip's shape, or straight lines between its stops.
      final hasShape = (shapePoints[trip.shapeId]?.length ?? 0) >= 2;
      final shapeKey = hasShape
          ? 's:${trip.shapeId}'
          : 'stops:${stopIds.join(',')}';
      final shapes = routeShapes[trip.route];
      var shape = shapes[shapeKey];
      if (shape == null) {
        final List<List<double>> line;
        if (hasShape) {
          final points = shapePoints[trip.shapeId]!
            ..sort((a, b) => a.$1.compareTo(b.$1));
          line = [
            for (final p in points) [_round(p.$2), _round(p.$3)],
          ];
        } else {
          line = [
            for (final s in stopIds)
              [stops[s][2] as double, stops[s][3] as double],
          ];
        }
        shape = routeShapeLines[trip.route].length;
        routeShapeLines[trip.route].add(line);
        shapes[shapeKey] = shape;
      }
      final line = routeShapeLines[trip.route][shape];
      final distances = projections.putIfAbsent(
        '${trip.route}|$shape|${stopIds.join(',')}',
        () => _alongShape(line, [
          for (final s in stopIds)
            (stops[s][2] as double, stops[s][3] as double),
        ]),
      );

      routeTrips[trip.route].add([
        trip.service,
        shape,
        trip.headsign,
        [for (final c in calls) c.$2],
        distances,
      ]);
      // The last stop is an arrival: nobody boards there.
      for (final c in calls.take(calls.length - 1)) {
        stopDepartures[c.$3].add([
          c.$2,
          trip.route,
          trip.headsign,
          trip.service,
        ]);
        stopRoutes[c.$3].add(trip.route);
      }
    }

    for (final builder in services.values) {
      for (final day in [
        if (builder.start > 0) builder.start,
        if (builder.end > 0) builder.end,
        ...builder.added,
      ]) {
        firstDay = math.min(firstDay, day);
        lastDay = math.max(lastDay, day);
      }
    }
    final feedInfo = zip.readText('feed_info.txt');
    if (feedInfo != null) {
      for (final row in _Table(feedInfo).rows) {
        firstDay = int.tryParse(row('feed_start_date')) ?? firstDay;
        lastDay = int.tryParse(row('feed_end_date')) ?? lastDay;
        break;
      }
    }
    if (lastDay == 0) throw const FormatException('No service days');

    out.createSync(recursive: true);
    Directory('${out.path}/stops').createSync();
    Directory('${out.path}/routes').createSync();
    void write(String name, Object json) =>
        File('${out.path}/$name').writeAsStringSync(jsonEncode(json));

    write('stops.json', [
      for (final (i, stop) in stops.indexed)
        [...stop, (stopRoutes[i].toList()..sort())],
    ]);
    write('routes.json', routes);
    write('services.json', [
      for (final id in serviceIds) services[id]!.build().toJson(),
    ]);
    for (final (i, departures) in stopDepartures.indexed) {
      if (departures.isEmpty) continue;
      departures.sort((a, b) => (a[0] as int).compareTo(b[0] as int));
      write('stops/$i.json', departures);
    }
    for (final (i, trips) in routeTrips.indexed) {
      if (trips.isEmpty) continue;
      write('routes/$i.json', {'shapes': routeShapeLines[i], 'trips': trips});
    }

    return GtfsImportResult(
      validFrom: _date(firstDay),
      validUntil: _date(lastDay),
      stops: stops.length,
    );
  }

  static DateTime _date(int day) =>
      DateTime(day ~/ 10000, day ~/ 100 % 100, day % 100);

  static double _round(double value) => (value * 1e6).roundToDouble() / 1e6;

  /// "25:10:00" as 90600; null when malformed.
  static int? _seconds(String value) {
    final parts = value.split(':');
    if (parts.length != 3) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final s = int.tryParse(parts[2]);
    if (h == null || m == null || s == null) return null;
    return h * 3600 + m * 60 + s;
  }

  /// Meters along [line] of each of [points], in order: each stop is
  /// searched from the previous one onwards, so a route that passes the
  /// same street twice keeps its direction.
  static List<int> _alongShape(
    List<List<double>> line,
    List<(double, double)> points,
  ) {
    final lat0 = line.first[0] * math.pi / 180;
    final kx = 111320 * math.cos(lat0);
    const ky = 110540.0;
    final xy = [for (final p in line) (p[1] * kx, p[0] * ky)];
    final cumulative = <double>[0];
    for (var i = 1; i < xy.length; i++) {
      final dx = xy[i].$1 - xy[i - 1].$1, dy = xy[i].$2 - xy[i - 1].$2;
      cumulative.add(cumulative.last + math.sqrt(dx * dx + dy * dy));
    }
    final result = <int>[];
    var from = 0;
    var previous = 0.0;
    for (final (lat, lon) in points) {
      final px = lon * kx, py = lat * ky;
      var best = double.infinity;
      var bestSegment = from;
      var bestAlong = previous;
      for (var i = from; i < xy.length - 1; i++) {
        final (ax, ay) = xy[i];
        final (bx, by) = xy[i + 1];
        final dx = bx - ax, dy = by - ay;
        final length2 = dx * dx + dy * dy;
        final t = length2 == 0
            ? 0.0
            : (((px - ax) * dx + (py - ay) * dy) / length2).clamp(0.0, 1.0);
        final qx = ax + t * dx - px, qy = ay + t * dy - py;
        final d = qx * qx + qy * qy;
        if (d < best) {
          best = d;
          bestSegment = i;
          bestAlong = cumulative[i] + t * math.sqrt(length2);
        }
      }
      from = bestSegment;
      previous = math.max(previous, bestAlong);
      result.add(previous.round());
    }
    return result;
  }
}

class _ServiceBuilder {
  int start = 0;
  int end = 0;
  int weekdays = 0;
  final added = <int>{};
  final removed = <int>{};

  ServiceDays build() => ServiceDays(
    start: start,
    end: end,
    weekdays: weekdays,
    added: added,
    removed: removed,
  );
}

class _Trip {
  _Trip(this.route, this.service, this.headsign, this.shapeId);

  final int route;
  final int service;
  final String headsign;
  final String shapeId;

  /// `(stop_sequence, seconds, stop index)`.
  final calls = <(int, int, int)>[];
}
