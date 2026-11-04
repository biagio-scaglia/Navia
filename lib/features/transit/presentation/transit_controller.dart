import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/json_http_client.dart';
import '../../../core/network/verified_download.dart';
import '../../../shared/models/geo_bounds.dart';
import '../../../shared/models/geo_point.dart';
import '../data/transit_store.dart';
import '../domain/schedule.dart';
import '../domain/transit.dart';

@immutable
class TransitState {
  const TransitState({
    this.info,
    this.progress,
    this.processing = false,
    this.failure,
  });

  /// The installed timetables, if any.
  final TransitInfo? info;

  /// Download progress from 0 to 1; absent when no download is running.
  final double? progress;

  /// The feed is downloaded and being processed on the device.
  final bool processing;
  final ServiceFailure? failure;

  bool get downloading => progress != null || processing;
}

/// Downloads, refreshes and deletes AMTAB's timetables.
///
/// The first download needs the user's consent. After that the timetables
/// are refreshed once a day, when the app starts, so that they never run
/// out: AMTAB publishes a new feed about every month.
class TransitController extends Notifier<TransitState> {
  /// Installed timetables older than this are refreshed.
  static const refreshAfter = Duration(days: 1);

  bool _cancelled = false;

  @override
  TransitState build() =>
      TransitState(info: ref.watch(transitStoreProvider)?.info());

  Future<void> download({bool quiet = false}) async {
    final store = ref.read(transitStoreProvider);
    if (store == null || state.downloading) return;
    _cancelled = false;
    state = TransitState(info: state.info, progress: 0);
    try {
      final info = await store.download(
        userAgent: ref.read(jsonHttpClientProvider).userAgent,
        isCancelled: () => _cancelled,
        onProgress: (received, total) {
          if (!ref.mounted) return;
          state = TransitState(
            info: state.info,
            progress: total == null || total == 0 ? 0 : received / total,
          );
        },
        onProcessing: () {
          if (ref.mounted) {
            state = TransitState(info: state.info, processing: true);
          }
        },
      );
      if (ref.mounted) state = TransitState(info: info);
    } on DownloadCancelled {
      if (ref.mounted) state = TransitState(info: state.info);
    } on Object catch (error) {
      logServiceError('AMTAB timetables', error);
      if (ref.mounted) {
        state = TransitState(
          info: state.info,
          // A failed automatic refresh keeps the old timetables quietly.
          failure: quiet
              ? null
              : error is ServiceException
              ? error.failure
              : ServiceFailure.unavailable,
        );
      }
    }
  }

  /// Refreshes installed timetables older than [refreshAfter].
  Future<void> refreshIfStale() async {
    final info = state.info;
    if (info == null) return;
    if (DateTime.now().difference(info.downloaded) < refreshAfter) return;
    await download(quiet: true);
  }

  void cancel() => _cancelled = true;

  Future<void> delete() async {
    await ref.read(transitStoreProvider)?.delete();
    if (ref.mounted) state = const TransitState();
  }
}

final transitProvider = NotifierProvider<TransitController, TransitState>(
  TransitController.new,
);

/// The parts of the timetables that every feature needs, loaded once per
/// installation.
@immutable
class TransitData {
  const TransitData({
    required this.stops,
    required this.stopRoutes,
    required this.routes,
    required this.services,
  });

  final List<TransitStop> stops;

  /// Route indexes by stop index.
  final List<List<int>> stopRoutes;
  final List<TransitRoute> routes;
  final List<ServiceDays> services;

  /// Stops closer than this to a selected point are taken as that stop: map
  /// labels and OpenStreetMap stops are rarely exactly where AMTAB puts
  /// them.
  static const matchMeters = 40.0;

  TransitStop? stopNear(GeoPoint point) {
    TransitStop? best;
    var bestDistance = matchMeters;
    for (final stop in stops) {
      if ((stop.point.latitude - point.latitude).abs() > 0.001) continue;
      final distance = stop.point.distanceTo(point);
      if (distance <= bestDistance) {
        bestDistance = distance;
        best = stop;
      }
    }
    return best;
  }

  List<TransitRoute> routesAt(TransitStop stop) => [
    if (stop.index < stopRoutes.length)
      for (final route in stopRoutes[stop.index])
        if (route < routes.length) routes[route],
  ];

  /// Whether [point] is in the area the timetables cover, with a margin.
  bool covers(GeoPoint point) => _bounds?.containsPoint(point) ?? false;

  GeoBounds? get _bounds {
    if (stops.isEmpty) return null;
    var south = 90.0, north = -90.0, west = 180.0, east = -180.0;
    for (final stop in stops) {
      final p = stop.point;
      if (p.latitude < south) south = p.latitude;
      if (p.latitude > north) north = p.latitude;
      if (p.longitude < west) west = p.longitude;
      if (p.longitude > east) east = p.longitude;
    }
    return GeoBounds.tryCreate(
      south: south - 0.01,
      west: west - 0.01,
      north: north + 0.01,
      east: east + 0.01,
    );
  }
}

final transitDataProvider = FutureProvider<TransitData?>((ref) async {
  final info = ref.watch(transitProvider.select((s) => s.info));
  final store = ref.watch(transitStoreProvider);
  if (info == null || store == null) return null;
  final (stops, stopRoutes, routes, services) = await (
    store.loadStops(),
    store.loadStopRoutes(),
    store.loadRoutes(),
    store.loadServices(),
  ).wait;
  return TransitData(
    stops: stops,
    stopRoutes: stopRoutes,
    routes: routes,
    services: services,
  );
});

/// The stored departures of a stop, by stop index.
final stopDeparturesProvider = FutureProvider.family<List<RawDeparture>, int>((
  ref,
  stop,
) async {
  ref.watch(transitProvider.select((s) => s.info));
  final store = ref.watch(transitStoreProvider);
  if (store == null) return const [];
  return store.loadDepartures(stop);
});

/// Shapes and trips of a route, by route index.
final routeScheduleProvider = FutureProvider.family<RouteSchedule?, int>((
  ref,
  route,
) async {
  ref.watch(transitProvider.select((s) => s.info));
  final store = ref.watch(transitStoreProvider);
  if (store == null) return null;
  return store.loadRoute(route);
});

/// The line shown on the map with its buses, by route index; null for
/// none.
class TransitLine extends Notifier<int?> {
  @override
  int? build() => null;

  void show(int route) => state = route;

  void hide() => state = null;
}

final transitLineProvider = NotifierProvider<TransitLine, int?>(
  TransitLine.new,
);

/// The buses of the shown line, where the timetable puts them, updated
/// every few seconds while a line is shown.
class TransitVehicles extends Notifier<List<TransitVehicle>> {
  static const interval = Duration(seconds: 3);

  Timer? _timer;

  @override
  List<TransitVehicle> build() {
    final route = ref.watch(transitLineProvider);
    final schedule = route == null
        ? null
        : ref.watch(routeScheduleProvider(route)).value;
    final services = ref.watch(transitDataProvider).value?.services;
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (schedule == null || services == null) return const [];
    List<TransitVehicle> compute() => TransitSchedule.vehicles(
      schedule,
      services: services,
      now: DateTime.now(),
    );
    _timer = Timer.periodic(interval, (_) {
      if (ref.mounted) state = compute();
    });
    return compute();
  }
}

final transitVehiclesProvider =
    NotifierProvider<TransitVehicles, List<TransitVehicle>>(
      TransitVehicles.new,
    );

/// Shapes and trips of the shown line, once read.
final shownLineScheduleProvider = Provider<RouteSchedule?>((ref) {
  final route = ref.watch(transitLineProvider);
  if (route == null) return null;
  return ref.watch(routeScheduleProvider(route)).value;
});
