import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks guidance instructions.
abstract interface class VoiceGuide {
  Future<void> speak(String text);
  Future<void> stop();
}

/// [VoiceGuide] on Android's text-to-speech engine, which works offline
/// with the voices installed on the device.
class TtsVoiceGuide implements VoiceGuide {
  TtsVoiceGuide() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(false);
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _configure();
      await _tts.stop();
      await _tts.speak(text);
    } on Exception {
      // No engine or voice: guidance stays visual.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Exception {
      // Nothing to stop.
    }
  }
}

final voiceGuideProvider = Provider<VoiceGuide>((ref) => TtsVoiceGuide());
