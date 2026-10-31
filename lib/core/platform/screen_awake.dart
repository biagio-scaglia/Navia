import 'package:flutter/services.dart';

/// Keeps the screen on, through the `navia/screen` channel in
/// `MainActivity`, while turn-by-turn guidance is active.
abstract final class ScreenAwake {
  static const channel = MethodChannel('navia/screen');

  static Future<void> set({required bool enabled}) async {
    try {
      await channel.invokeMethod<void>('keepOn', {'enabled': enabled});
    } on PlatformException {
      // Not essential: the system timeout simply applies.
    } on MissingPluginException {
      // Not available on this platform.
    }
  }
}
