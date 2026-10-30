import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/navia_icon.dart';
import '../../location/presentation/location_failure_messages.dart';
import '../domain/navigation_models.dart';
import 'navigation_controller.dart';

extension TravelModeLabels on TravelMode {
  String get label => switch (this) {
    TravelMode.driving => AppStrings.modeDriving,
    TravelMode.cycling => AppStrings.modeCycling,
    TravelMode.walking => AppStrings.modeWalking,
  };

  NaviaIcons get icon => switch (this) {
    TravelMode.driving => NaviaIcons.car,
    TravelMode.cycling => NaviaIcons.bike,
    TravelMode.walking => NaviaIcons.walk,
  };
}

extension WaypointLabels on Waypoint {
  String get title => switch (this) {
    CurrentLocationWaypoint() => AppStrings.yourLocation,
    PointWaypoint(:final label) => label ?? AppStrings.mapPoint,
  };

  /// Secondary line: the place description or the coordinates.
  String? get subtitle => switch (this) {
    CurrentLocationWaypoint() => null,
    PointWaypoint(:final label, :final description, :final point) =>
      label == null ? point.toDisplayString() : description,
  };
}

extension RouteErrorMessages on RouteError {
  String get message => switch (this) {
    RouteServiceError(failure: ServiceFailure.noResult) => AppStrings.noRoute,
    RouteServiceError(:final failure) => failure.message,
    RouteLocationError(:final failure) => failure.message,
    RouteSamePointsError() => AppStrings.samePoints,
  };

  bool get isRetryable => switch (this) {
    RouteServiceError(:final failure) => failure.isRetryable,
    RouteLocationError() => true,
    RouteSamePointsError() => false,
  };
}
