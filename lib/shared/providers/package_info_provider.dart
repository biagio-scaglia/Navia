import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Application name and version, loaded once during bootstrap.
final packageInfoProvider = Provider<PackageInfo>(
  (ref) => throw UnimplementedError(
    'packageInfoProvider must be overridden during bootstrap.',
  ),
);
