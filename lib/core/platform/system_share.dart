import 'package:flutter/services.dart';

/// Android's share sheet, through the `navia/share` channel implemented in
/// `MainActivity`.
abstract final class SystemShare {
  static const channel = MethodChannel('navia/share');

  /// Opens the share sheet with [text]. Returns false when sharing is not
  /// available, e.g. on a platform without the channel.
  static Future<bool> shareText(String text, {String? subject}) async {
    try {
      final shared = await channel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': ?subject,
      });
      return shared ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
