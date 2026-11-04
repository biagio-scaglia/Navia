import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the ongoing guidance notification shows.
@immutable
class GuidanceNotice {
  const GuidanceNotice({required this.title, required this.text});

  /// The next maneuver, e.g. "Tra 200 m svolta a destra in Via Sparano".
  final String title;

  /// What is left of the route.
  final String text;

  Map<String, String> toMap() => {'title': title, 'text': text};

  @override
  bool operator ==(Object other) =>
      other is GuidanceNotice && other.title == title && other.text == text;

  @override
  int get hashCode => Object.hash(title, text);
}

/// Keeps guidance running with the screen locked or another app open: a
/// foreground service with an ongoing notification, from the
/// `io.github.biagioscaglia.navia.guidance` Kotlin package.
abstract interface class BackgroundGuidance {
  /// Starts the service; false when Android refused it, in which case
  /// guidance still works while Navia is open.
  Future<bool> start(GuidanceNotice notice);

  Future<void> update(GuidanceNotice notice);

  Future<void> stop();

  /// Whether the notification can be shown (Android 13+ asks the user).
  Future<bool> notificationsAllowed();

  /// Asks for the notification permission; true when granted.
  Future<bool> requestNotifications();

  /// The user tapped "Termina" in the notification.
  Stream<void> get stopRequests;
}

/// [BackgroundGuidance] over the `navia/guidance` channel of
/// `MainActivity`. Without the channel (tests, other platforms) every call
/// quietly does nothing.
class ChannelBackgroundGuidance implements BackgroundGuidance {
  ChannelBackgroundGuidance([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('navia/guidance') {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopRequested') _stops.add(null);
    });
  }

  final MethodChannel _channel;
  final _stops = StreamController<void>.broadcast();

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> start(GuidanceNotice notice) async =>
      await _call<bool>('start', notice.toMap()) ?? false;

  @override
  Future<void> update(GuidanceNotice notice) =>
      _call<void>('update', notice.toMap());

  @override
  Future<void> stop() => _call<void>('stop');

  @override
  Future<bool> notificationsAllowed() async =>
      await _call<bool>('notificationsAllowed') ?? true;

  @override
  Future<bool> requestNotifications() async =>
      await _call<bool>('requestNotifications') ?? false;

  @override
  Stream<void> get stopRequests => _stops.stream;
}

/// Lowers other audio, such as music, while an instruction is spoken,
/// through the `navia/guidance` channel (transient audio focus that lets
/// other players duck instead of pausing).
abstract final class AudioDucking {
  static const _channel = MethodChannel('navia/guidance');

  static Future<void> duck() => _invoke('duck');

  static Future<void> release() => _invoke('unduck');

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<Object?>(method);
    } on PlatformException {
      // Not essential: the voice simply speaks over the music.
    } on MissingPluginException {
      // Not available on this platform.
    }
  }
}

final backgroundGuidanceProvider = Provider<BackgroundGuidance>(
  (ref) => ChannelBackgroundGuidance(),
);
