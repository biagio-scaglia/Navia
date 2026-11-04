import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Reads the files of a ZIP archive, enough for GTFS feeds: stored and
/// deflated entries, no encryption, no ZIP64. Written on `dart:io` to
/// avoid a dependency for one small format.
class ZipReader {
  ZipReader._(this._bytes, this._entries);

  /// Parses the central directory of [bytes]; throws [FormatException]
  /// when it is not a ZIP archive this reader supports.
  factory ZipReader(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    // The end of central directory record is in the last 64 kB + 22 bytes.
    var end = -1;
    for (var i = bytes.length - 22; i >= 0 && i >= bytes.length - 65557; i--) {
      if (data.getUint32(i, Endian.little) == 0x06054b50) {
        end = i;
        break;
      }
    }
    if (end < 0) throw const FormatException('Not a ZIP archive');
    final count = data.getUint16(end + 10, Endian.little);
    var offset = data.getUint32(end + 16, Endian.little);
    final entries = <String, _Entry>{};
    for (var i = 0; i < count; i++) {
      if (offset + 46 > bytes.length ||
          data.getUint32(offset, Endian.little) != 0x02014b50) {
        throw const FormatException('Broken ZIP central directory');
      }
      final method = data.getUint16(offset + 10, Endian.little);
      final compressed = data.getUint32(offset + 20, Endian.little);
      final size = data.getUint32(offset + 24, Endian.little);
      final nameLength = data.getUint16(offset + 28, Endian.little);
      final extraLength = data.getUint16(offset + 30, Endian.little);
      final commentLength = data.getUint16(offset + 32, Endian.little);
      final local = data.getUint32(offset + 42, Endian.little);
      final name = utf8.decode(
        bytes.sublist(offset + 46, offset + 46 + nameLength),
        allowMalformed: true,
      );
      entries[name] = _Entry(method, compressed, size, local);
      offset += 46 + nameLength + extraLength + commentLength;
    }
    return ZipReader._(bytes, entries);
  }

  /// Uncompressed size above which an entry is refused, against archives
  /// built to fill the storage.
  static const maxEntrySize = 200 * 1024 * 1024;

  final Uint8List _bytes;
  final Map<String, _Entry> _entries;

  Iterable<String> get names => _entries.keys;

  /// The uncompressed bytes of [name], or null when it is not in the
  /// archive.
  Uint8List? read(String name) {
    final entry = _entries[name];
    if (entry == null) return null;
    if (entry.size > maxEntrySize) {
      throw const FormatException('ZIP entry too large');
    }
    final data = ByteData.sublistView(_bytes);
    final local = entry.localOffset;
    if (local + 30 > _bytes.length ||
        data.getUint32(local, Endian.little) != 0x04034b50) {
      throw const FormatException('Broken ZIP entry');
    }
    final start =
        local +
        30 +
        data.getUint16(local + 26, Endian.little) +
        data.getUint16(local + 28, Endian.little);
    if (start + entry.compressed > _bytes.length) {
      throw const FormatException('Truncated ZIP entry');
    }
    final raw = Uint8List.sublistView(_bytes, start, start + entry.compressed);
    final Uint8List out;
    switch (entry.method) {
      case 0:
        out = Uint8List.fromList(raw);
      case 8:
        out = Uint8List.fromList(ZLibDecoder(raw: true).convert(raw));
      default:
        throw const FormatException('Unsupported ZIP compression');
    }
    if (out.length != entry.size) {
      throw const FormatException('ZIP entry size mismatch');
    }
    return out;
  }

  /// [name] as UTF-8 text without a byte order mark, or null.
  String? readText(String name) {
    final bytes = read(name);
    if (bytes == null) return null;
    final text = utf8.decode(bytes, allowMalformed: true);
    return text.startsWith('﻿') ? text.substring(1) : text;
  }
}

class _Entry {
  const _Entry(this.method, this.compressed, this.size, this.localOffset);

  final int method;
  final int compressed;
  final int size;
  final int localOffset;
}
