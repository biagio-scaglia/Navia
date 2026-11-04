import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Writes a ZIP archive of [files]: deflated when [deflate], else stored.
Uint8List zipOf(Map<String, String> files, {bool deflate = true}) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  for (final MapEntry(key: name, value: text) in files.entries) {
    final data = utf8.encode(text);
    final body = deflate ? ZLibEncoder(raw: true).convert(data) : data;
    final nameBytes = utf8.encode(name);
    final offset = out.length;
    final local = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(8, deflate ? 8 : 0, Endian.little)
      ..setUint32(18, body.length, Endian.little)
      ..setUint32(22, data.length, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little);
    out
      ..add(local.buffer.asUint8List())
      ..add(nameBytes)
      ..add(body);
    final entry = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(10, deflate ? 8 : 0, Endian.little)
      ..setUint32(20, body.length, Endian.little)
      ..setUint32(24, data.length, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(entry.buffer.asUint8List())
      ..add(nameBytes);
  }
  final centralOffset = out.length;
  final centralBytes = central.toBytes();
  out.add(centralBytes);
  final end = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, files.length, Endian.little)
    ..setUint16(10, files.length, Endian.little)
    ..setUint32(12, centralBytes.length, Endian.little)
    ..setUint32(16, centralOffset, Endian.little);
  out.add(end.buffer.asUint8List());
  return out.toBytes();
}

String _day(DateTime d) =>
    '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

String _time(int seconds) {
  final h = seconds ~/ 3600, m = seconds ~/ 60 % 60, s = seconds % 60;
  return [h, m, s].map((v) => v.toString().padLeft(2, '0')).join(':');
}

/// Two stops 1 km apart on a straight street in Bari, line "02/" from A
/// to B every 10 minutes from 00:00 to 26:00, running every day around
/// [today]; a quoted stop name with a comma checks the CSV reader.
Map<String, String> tinyFeed(DateTime today) {
  final start = today.subtract(const Duration(days: 3));
  final end = today.add(const Duration(days: 3));
  final trips = StringBuffer(
    'route_id,service_id,trip_id,trip_headsign,shape_id\n',
  );
  final times = StringBuffer(
    'trip_id,arrival_time,departure_time,stop_id,stop_sequence\n',
  );
  for (var t = 0, i = 0; t <= 26 * 3600; t += 600, i++) {
    trips.writeln('R2,S,T$i,Stazione,SH');
    times
      ..writeln('T$i,${_time(t)},${_time(t)},A,1')
      ..writeln('T$i,${_time(t + 300)},${_time(t + 300)},B,2');
  }
  return {
    'agency.txt':
        'agency_id,agency_name,agency_url,agency_timezone\n'
        'AMTAB,Amtab,http://www.amtab.it,Europe/Rome\n',
    'stops.txt':
        'stop_id,stop_name,stop_lat,stop_lon\n'
        'A,"Piccinni, Teatro",41.120000,16.870000\n'
        'B,Stazione,41.129000,16.870000\n',
    'routes.txt':
        'route_id,route_short_name,route_long_name,route_color\n'
        'R2,02/,Piscine - S.Anna,5F9EA0\n',
    'calendar.txt':
        'service_id,monday,tuesday,wednesday,thursday,friday,saturday,'
        'sunday,start_date,end_date\n'
        'S,1,1,1,1,1,1,1,${_day(start)},${_day(end)}\n',
    'trips.txt': trips.toString(),
    'stop_times.txt': times.toString(),
    'shapes.txt':
        'shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence\n'
        'SH,41.120000,16.870000,1\n'
        'SH,41.124500,16.870000,2\n'
        'SH,41.129000,16.870000,3\n',
  };
}
