import '../../../core/l10n/app_strings.dart';
import '../domain/location_models.dart';

extension LocationFailureMessages on LocationFailure {
  String get message => switch (this) {
    LocationFailure.serviceDisabled => AppStrings.locationServiceDisabled,
    LocationFailure.permissionDenied => AppStrings.locationPermissionDenied,
    LocationFailure.permissionDeniedForever =>
      AppStrings.locationPermissionDeniedForever,
    LocationFailure.unavailable => AppStrings.locationUnavailable,
  };

  /// Label of the action that can resolve the failure, if any.
  String? get actionLabel => switch (this) {
    LocationFailure.serviceDisabled => AppStrings.enable,
    LocationFailure.permissionDeniedForever => AppStrings.openSettings,
    LocationFailure.permissionDenied || LocationFailure.unavailable => null,
  };
}
