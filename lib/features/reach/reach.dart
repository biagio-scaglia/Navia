import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config.dart';
import '../../core/errors/app_failure.dart';
import '../../core/network/json_http_client.dart';
import '../../shared/models/geo_point.dart';
import '../navigation/domain/navigation_models.dart';

/// The area reachable within [minutes], as polygons (outer rings).
@immutable
class ReachContour {
  const ReachContour({required this.minutes, required this.rings});

  final int minutes;

  /// Closed rings of `[longitude, latitude]` positions.
  final List<List<List<double>>> rings;
}

/// Computes reachable areas (isochrones) with the Valhalla routing engine.
class ReachRepository {
  ReachRepository(this._client, {required this.endpoint});

  final JsonHttpClient _client;
  final String endpoint;

  static const minutes = [5, 10, 15];

  Future<List<ReachContour>> reachable(GeoPoint from, TravelMode mode) async {
    final request = {
      'locations': [
        {'lat': from.latitude, 'lon': from.longitude},
      ],
      'costing': switch (mode) {
        TravelMode.driving => 'auto',
        TravelMode.cycling => 'bicycle',
        TravelMode.walking => 'pedestrian',
      },
      'contours': [
        for (final value in minutes) {'time': value},
      ],
      'polygons': true,
    };
    final uri = Uri.parse(
      endpoint,
    ).replace(queryParameters: {'json': jsonEncode(request)});
    final response = await _client.getJson(uri);
    if (response.statusCode >= 400) {
      throw ServiceException(
        response.statusCode == 429
            ? ServiceFailure.rateLimited
            : ServiceFailure.invalidRequest,
        response.statusCode,
      );
    }
    final contours = parse(response.body);
    if (contours.isEmpty) {
      throw const ServiceException(ServiceFailure.noResult);
    }
    return contours;
  }

  @visibleForTesting
  static List<ReachContour> parse(Map<String, dynamic> body) {
    final features = body['features'];
    if (features is! List) return const [];
    final contours = <ReachContour>[];
    for (final feature in features) {
      if (feature is! Map) continue;
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      final contour = properties is Map ? properties['contour'] : null;
      if (contour is! num || geometry is! Map) continue;
      final polygons = switch (geometry['type']) {
        'Polygon' => [geometry['coordinates']],
        'MultiPolygon' => geometry['coordinates'],
        _ => null,
      };
      if (polygons is! List) continue;
      final rings = <List<List<double>>>[];
      for (final polygon in polygons) {
        if (polygon is! List || polygon.isEmpty) continue;
        final ring = _ring(polygon.first);
        if (ring != null) rings.add(ring);
      }
      if (rings.isNotEmpty) {
        contours.add(ReachContour(minutes: contour.round(), rings: rings));
      }
    }
    // Largest first, so smaller areas are drawn on top.
    contours.sort((a, b) => b.minutes.compareTo(a.minutes));
    return contours;
  }

  static List<List<double>>? _ring(Object? positions) {
    if (positions is! List || positions.length < 4) return null;
    final ring = <List<double>>[];
    for (final position in positions) {
      final point = GeoPoint.tryParseLngLat(position);
      if (point == null) return null;
      ring.add(point.toLngLat());
    }
    return ring;
  }
}

enum ReachStatus { idle, loading, ready, failed }

@immutable
class ReachState {
  const ReachState({
    this.mode = TravelMode.walking,
    this.status = ReachStatus.idle,
    this.contours = const [],
    this.failure,
  });

  final TravelMode mode;
  final ReachStatus status;
  final List<ReachContour> contours;
  final ServiceFailure? failure;

  ReachState copyWith({
    TravelMode? mode,
    ReachStatus? status,
    List<ReachContour>? contours,
    ServiceFailure? Function()? failure,
  }) => ReachState(
    mode: mode ?? this.mode,
    status: status ?? this.status,
    contours: contours ?? this.contours,
    failure: failure == null ? this.failure : failure(),
  );
}

/// "Dove arrivo in 15 minuti": computed only when the user asks.
class ReachController extends Notifier<ReachState> {
  int _generation = 0;

  @override
  ReachState build() => const ReachState();

  void setMode(TravelMode mode) => state = state.copyWith(mode: mode);

  Future<void> show(GeoPoint from) async {
    final repository = ref.read(reachRepositoryProvider);
    if (repository == null) return;
    final generation = ++_generation;
    state = state.copyWith(status: ReachStatus.loading, failure: () => null);
    try {
      final contours = await repository.reachable(from, state.mode);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(status: ReachStatus.ready, contours: contours);
    } on ServiceException catch (error) {
      logServiceError('reach', error);
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        status: ReachStatus.failed,
        contours: const [],
        failure: () => error.failure,
      );
    }
  }

  void hide() {
    _generation++;
    state = ReachState(mode: state.mode);
  }
}

final reachRepositoryProvider = Provider<ReachRepository?>((ref) {
  const endpoint = AppConfig.isochroneUrl;
  if (endpoint.isEmpty) return null;
  return ReachRepository(ref.watch(jsonHttpClientProvider), endpoint: endpoint);
});

final reachProvider = NotifierProvider<ReachController, ReachState>(
  ReachController.new,
);
