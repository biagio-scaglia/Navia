import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/map/presentation/map_providers.dart';

void main() {
  test('measures the turn from north either way', () {
    expect(MapBearing.offNorth(0), 0);
    expect(MapBearing.offNorth(30), 30);
    expect(MapBearing.offNorth(330), 30);
    expect(MapBearing.offNorth(-30), 30);
    expect(MapBearing.offNorth(180), 180);
  });

  test('ignores tiny changes but always reaches north', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bearing = container.read(mapBearingProvider.notifier)..update(40);
    expect(container.read(mapBearingProvider), 40);

    bearing.update(40.2);
    expect(container.read(mapBearingProvider), 40);

    bearing
      ..update(0.3)
      ..update(0);
    expect(container.read(mapBearingProvider), 0);
  });
}
