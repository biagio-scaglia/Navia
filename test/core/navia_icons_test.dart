import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:navia/core/widgets/navia_icon.dart';
import 'package:navia/core/widgets/navia_logo.dart';

void main() {
  test('every icon has an SVG asset', () {
    for (final icon in NaviaIcons.values) {
      expect(File(icon.asset).existsSync(), isTrue, reason: icon.asset);
    }
  });

  test('every icon asset is referenced by the enum', () {
    final referenced = NaviaIcons.values.map((icon) => icon.asset).toSet();
    final files = Directory('assets/icons')
        .listSync()
        .map((file) => file.path.replaceAll(r'\', '/'))
        .where((path) => path.endsWith('.svg'));
    expect(files.toSet(), referenced);
  });

  test('the logo asset exists', () {
    expect(File(NaviaLogoMark.asset).existsSync(), isTrue);
  });
}
