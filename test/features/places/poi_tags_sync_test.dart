import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/places/domain/poi_category.dart';

void main() {
  test('the offline data generator selects the same tags as the app', () {
    final json =
        jsonDecode(File('tool/places/poi_tags.json').readAsStringSync())
            as Map<String, dynamic>;

    expect(json.keys.toSet(), PoiCategory.values.map((c) => c.name).toSet());
    for (final category in PoiCategory.values) {
      final tags = (json[category.name] as Map<String, dynamic>).map(
        (key, values) => MapEntry(key, List<String>.from(values as List)),
      );
      expect(tags, category.tags, reason: category.name);
    }
  });
}
