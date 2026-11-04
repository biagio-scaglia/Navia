import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'background_guidance.dart';

/// Speaks guidance instructions.
abstract interface class VoiceGuide {
  Future<void> speak(String text);
  Future<void> stop();
}

/// [VoiceGuide] on Android's text-to-speech engine, which works offline
/// with the voices installed on the device. Music and other audio are
/// lowered while it speaks, then restored.
class TtsVoiceGuide implements VoiceGuide {
  TtsVoiceGuide() : _tts = FlutterTts();

  final FlutterTts _tts;
  bool _configured = false;

  /// Bumped by every [speak] and [stop], so that an interrupted sentence
  /// does not restore the music under the next one.
  int _utterance = 0;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    await _tts.setLanguage('it-IT');
    await _tts.setSpeechRate(0.5);
    // The navigation audio stream, which the system and car audio treat
    // as guidance.
    await _tts.setAudioAttributesForNavigation();
    await _tts.awaitSpeakCompletion(true);
  }

  @override
  Future<void> speak(String text) async {
    final utterance = ++_utterance;
    try {
      await _configure();
      await _tts.stop();
      await AudioDucking.duck();
      await _tts.speak(text);
    } on Exception {
      // No engine or voice: guidance stays visual.
    } finally {
      if (utterance == _utterance) await AudioDucking.release();
    }
  }

  @override
  Future<void> stop() async {
    _utterance++;
    try {
      await _tts.stop();
    } on Exception {
      // Nothing to stop.
    } finally {
      await AudioDucking.release();
    }
  }
}

final voiceGuideProvider = Provider<VoiceGuide>((ref) => TtsVoiceGuide());
