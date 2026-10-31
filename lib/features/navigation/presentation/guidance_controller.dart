import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/screen_awake.dart';
import '../../../core/platform/voice_guide.dart';
import '../../location/domain/location_models.dart';
import '../../location/presentation/location_controller.dart';
import '../domain/guidance_tracker.dart';
import '../domain/navigation_models.dart';
import 'navigation_controller.dart';
import 'route_instructions.dart';

@immutable
class GuidanceState {
  const GuidanceState({
    this.active = false,
    this.nextStep,
    this.distanceToManeuver = 0,
    this.remainingMeters = 0,
    this.muted = false,
    this.rerouting = false,
  });

  final bool active;

  /// The maneuver to perform next.
  final RouteStep? nextStep;
  final double distanceToManeuver;
  final double remainingMeters;
  final bool muted;
  final bool rerouting;

  GuidanceState copyWith({
    bool? active,
    RouteStep? Function()? nextStep,
    double? distanceToManeuver,
    double? remainingMeters,
    bool? muted,
    bool? rerouting,
  }) => GuidanceState(
    active: active ?? this.active,
    nextStep: nextStep == null ? this.nextStep : nextStep(),
    distanceToManeuver: distanceToManeuver ?? this.distanceToManeuver,
    remainingMeters: remainingMeters ?? this.remainingMeters,
    muted: muted ?? this.muted,
    rerouting: rerouting ?? this.rerouting,
  );
}

/// Turn-by-turn guidance along the calculated route, from the device
/// location, with spoken instructions.
///
/// It runs only while the app is in the foreground: location updates stop
/// when the app is hidden, and Navia never asks for background location.
class GuidanceController extends Notifier<GuidanceState> {
  /// Minimum time between automatic recalculations.
  static const rerouteInterval = Duration(seconds: 15);

  GuidanceTracker? _tracker;
  DateTime? _lastReroute;

  VoiceGuide get _voice => ref.read(voiceGuideProvider);
  NavigationController get _navigation =>
      ref.read(navigationControllerProvider.notifier);

  @override
  GuidanceState build() {
    ref
      ..listen(locationControllerProvider.select((s) => s.position), (
        _,
        position,
      ) {
        if (position != null) _onPosition(position);
      })
      ..listen(navigationControllerProvider.select((s) => s.route), (_, route) {
        if (!state.active) return;
        if (route == null) {
          // The route was cleared or is being recalculated.
          if (!state.rerouting) unawaited(stop());
          return;
        }
        // The first route of a session is announced from its departure.
        _follow(route, announce: _tracker == null);
        state = state.copyWith(rerouting: false);
      });
    return const GuidanceState();
  }

  /// Starts guidance. The route is first recalculated from the device
  /// location when it starts elsewhere.
  Future<void> start() async {
    final navigation = ref.read(navigationControllerProvider);
    final route = navigation.route;
    if (route == null || route.steps.isEmpty) return;
    state = state.copyWith(active: true, rerouting: false);
    unawaited(ScreenAwake.set(enabled: true));

    if (navigation.origin is! CurrentLocationWaypoint) {
      state = state.copyWith(rerouting: true);
      _navigation.setOrigin(const CurrentLocationWaypoint());
      await _navigation.calculate();
      return;
    }
    _follow(route, announce: true);
    final position = await ref
        .read(locationControllerProvider.notifier)
        .locate();
    if (position != null && ref.mounted) _onPosition(position);
  }

  Future<void> stop() async {
    _tracker = null;
    state = GuidanceState(muted: state.muted);
    await ScreenAwake.set(enabled: false);
    await _voice.stop();
  }

  void toggleMuted() {
    state = state.copyWith(muted: !state.muted);
    if (state.muted) unawaited(_voice.stop());
  }

  void _follow(NavRoute route, {required bool announce}) {
    final tracker = GuidanceTracker(
      route,
      describe: RouteInstructions.text,
      describeAhead: RouteInstructions.spokenAhead,
    );
    _tracker = tracker;
    final steps = route.steps;
    state = state.copyWith(
      nextStep: () => steps.length > 1 ? steps[1] : null,
      remainingMeters: route.distanceMeters,
    );
    if (announce) _say(tracker.departure);
  }

  void _onPosition(UserPosition position) {
    final tracker = _tracker;
    if (!state.active || tracker == null || state.rerouting) return;
    final update = tracker.update(position.point);
    final steps = tracker.route.steps;
    state = state.copyWith(
      nextStep: () => steps.isEmpty ? null : steps[update.nextStepIndex],
      distanceToManeuver: update.distanceToManeuver,
      remainingMeters: update.remainingMeters,
    );
    _say(update.announcement);
    if (update.arrived) {
      unawaited(stop());
    } else if (update.offRoute) {
      unawaited(_reroute());
    }
  }

  Future<void> _reroute() async {
    final now = DateTime.now();
    final last = _lastReroute;
    if (last != null && now.difference(last) < rerouteInterval) return;
    _lastReroute = now;
    state = state.copyWith(rerouting: true);
    _say(RouteInstructions.rerouting);
    _navigation.setOrigin(const CurrentLocationWaypoint());
    await _navigation.calculate();
    if (!ref.mounted) return;
    // A failed calculation leaves no route: guidance stops and the panel
    // explains the error.
    if (ref.read(navigationControllerProvider).route == null) {
      await stop();
    }
  }

  void _say(String? text) {
    if (text == null || state.muted) return;
    unawaited(_voice.speak(text));
  }
}

final guidanceProvider = NotifierProvider<GuidanceController, GuidanceState>(
  GuidanceController.new,
);
