import 'package:flutter_test/flutter_test.dart';
import 'package:navia/features/navigation/data/osrm_routing_repository.dart';
import 'package:navia/features/navigation/domain/navigation_models.dart';
import 'package:navia/features/navigation/presentation/route_instructions.dart';
import 'package:navia/shared/models/geo_point.dart';

const _here = GeoPoint(latitude: 41.118, longitude: 16.862);

RouteStep _step(
  ManeuverKind kind, {
  ManeuverDirection? direction,
  String? street,
  int? exit,
}) => RouteStep(
  kind: kind,
  location: _here,
  distanceMeters: 100,
  direction: direction,
  streetName: street,
  exit: exit,
);

void main() {
  test('reads maneuvers from an OSRM route', () {
    final route = OsrmRoutingRepository.parse({
      'code': 'Ok',
      'routes': [
        {
          'distance': 1552.0,
          'duration': 240.0,
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [16.862, 41.118],
              [16.8732, 41.1236],
            ],
          },
          'legs': [
            {
              'steps': [
                {
                  'distance': 24.0,
                  'name': '',
                  'maneuver': {
                    'type': 'depart',
                    'modifier': 'left',
                    'location': [16.862, 41.118],
                  },
                },
                {
                  'distance': 308.0,
                  'name': 'Corso Italia',
                  'maneuver': {
                    'type': 'turn',
                    'modifier': 'right',
                    'location': [16.8622, 41.1182],
                  },
                },
                {
                  'distance': 120.0,
                  'name': 'Via Sparano',
                  'maneuver': {
                    'type': 'roundabout',
                    'exit': 2,
                    'location': [16.866, 41.12],
                  },
                },
                {'distance': 5, 'maneuver': 'broken'},
                {
                  'distance': 0.0,
                  'name': 'Via Alberto Sordi',
                  'maneuver': {
                    'type': 'arrive',
                    'location': [16.8732, 41.1236],
                  },
                },
              ],
            },
          ],
        },
      ],
    }, TravelMode.driving);

    expect(route.steps.map((s) => s.kind), [
      ManeuverKind.depart,
      ManeuverKind.turn,
      ManeuverKind.roundabout,
      ManeuverKind.arrive,
    ]);
    expect(route.steps[1].direction, ManeuverDirection.right);
    expect(route.steps[1].streetName, 'Corso Italia');
    expect(route.steps[0].streetName, isNull);
    expect(route.steps[2].exit, 2);
  });

  group('Italian instructions', () {
    test('describe turns, roundabouts, forks and arrival', () {
      expect(
        RouteInstructions.text(
          _step(
            ManeuverKind.turn,
            direction: ManeuverDirection.right,
            street: 'Corso Italia',
          ),
        ),
        'Svolta a destra in Corso Italia',
      );
      expect(
        RouteInstructions.text(
          _step(ManeuverKind.roundabout, exit: 2, street: 'Via Sparano'),
        ),
        'Alla rotonda prendi la seconda uscita in Via Sparano',
      );
      expect(
        RouteInstructions.text(
          _step(ManeuverKind.fork, direction: ManeuverDirection.slightLeft),
        ),
        'Al bivio tieni la sinistra',
      );
      expect(
        RouteInstructions.text(
          _step(
            ManeuverKind.newName,
            direction: ManeuverDirection.straight,
            street: 'Via de Rossi',
          ),
        ),
        'Continua dritto su Via de Rossi',
      );
      expect(
        RouteInstructions.text(_step(ManeuverKind.depart)),
        'Parti seguendo il percorso',
      );
      expect(
        RouteInstructions.text(_step(ManeuverKind.arrive)),
        'Sei arrivato a destinazione',
      );
    });

    test('announce distances in rounded spoken form', () {
      expect(RouteInstructions.spokenDistance(47), '50 metri');
      expect(RouteInstructions.spokenDistance(287), '300 metri');
      expect(RouteInstructions.spokenDistance(1000), '1 chilometro');
      expect(RouteInstructions.spokenDistance(1530), '1,5 chilometri');
      expect(
        RouteInstructions.spokenAhead(
          _step(ManeuverKind.turn, direction: ManeuverDirection.left),
          210,
        ),
        'Tra 200 metri, svolta a sinistra',
      );
    });
  });
}
