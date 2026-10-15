import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../l10n/l10n.dart';

/// Spoken money alerts. They can't be muted in the app, so a driver always hears a fare land.
///
/// With the app closed, Android plays the recorded clip set as the notification channel's sound
/// (res/raw/voice_*.wav, on the alarm stream so it's heard on silent; MainActivity.kt). With the
/// app open, there's no system notification, so the app speaks the full sentence, amount
/// included, through the phone's text-to-speech, falling back to the same clip.
///
/// The sentence is in the app's language when the phone has a voice for it (Pidgin uses the
/// Nigerian English voice). Few phones have Yoruba or Hausa voices; without one it's said in
/// English rather than read out badly by an English voice.
abstract final class Voice {
  // Under `flutter test` there is no speech engine or audio plugin.
  static final bool _silent = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  static FlutterTts? _tts;
  static bool? _ttsWorks;

  /// The app language the speech engine is set up for, and whether it had a voice for it.
  static Lang? _voiceFor;
  static bool _native = false;
  static AudioPlayer? _player;
  static Future<void> _queue = Future.value();

  /// Push kinds that are spoken, and the clip for each.
  static const clips = {
    'fare.received': 'sounds/voice_fare_received.wav',
    'wallet.funded': 'sounds/voice_wallet_funded.wav',
    'payout.paid': 'sounds/voice_payout_sent.wav',
  };

  /// "600 naira", "1,250 naira 50 kobo".
  static String amount(int kobo) {
    final n = kobo ~/ 100;
    final k = kobo % 100;
    return '$n naira${k == 0 ? '' : ' $k kobo'}';
  }

  /// What to say for a push of [kind] carrying [data] (amountKobo, riders), or null if it isn't spoken.
  static String? sentenceFor(String kind, Map<String, dynamic> data) {
    final kobo = int.tryParse('${data['amountKobo'] ?? ''}');
    final riders = int.tryParse('${data['riders'] ?? ''}') ?? 1;
    switch (kind) {
      case 'fare.received':
        if (kobo == null) return 'Payment received.';
        return 'Payment received. ${amount(kobo)}${riders > 1 ? ', from $riders riders' : ''}.';
      case 'wallet.funded':
        return kobo == null ? 'Your wallet has been topped up.' : 'Your wallet has been topped up with ${amount(kobo)}.';
      case 'payout.paid':
        return kobo == null ? 'Your payout has been sent to your bank.' : '${amount(kobo)} has been sent to your bank.';
    }
    return null;
  }

  /// Speaks the alert for a push that arrived with the app open. Does nothing for other kinds.
  static Future<void> announce(String kind, Map<String, dynamic> data) {
    final text = sentenceFor(kind, data);
    final clip = clips[kind];
    if (text == null || clip == null) return Future.value();
    return say(text, clip: clip);
  }

  /// Says [text]; if the phone can't speak, plays [clip] (an asset under assets/).
  /// Alerts queue up, so two fares in a row are both heard in full.
  static Future<void> say(String text, {required String clip}) => _enqueue((native) => native ? tr(text) : text, clip);

  /// Says several English sentences, each a template with its values (`('You made {amount}.', {...})`),
  /// translated one by one when the phone has a voice for the app's language.
  static Future<void> saySentences(List<(String, Map<String, Object?>?)> parts, {required String clip}) => _enqueue(
    (native) => parts.map((p) => native ? tr(p.$1, p.$2 ?? const {}) : fill(p.$1, p.$2 ?? const {})).join(' '),
    clip,
  );

  static Future<void> _enqueue(String Function(bool native) text, String clip) {
    if (_silent) return Future.value();
    return _queue = _queue.then((_) => _speak(text, clip)).catchError((_) {});
  }

  static Future<void> _speak(String Function(bool native) text, String clip) async {
    if (await _ready()) {
      try {
        await _useLanguage(L10n.instance.lang);
        final r = await _tts!.speak(text(_native));
        if (r == 1) return;
      } catch (_) {}
    }
    await _play(clip);
  }

  static Future<bool> _ready() async {
    if (_ttsWorks != null) return _ttsWorks!;
    try {
      final tts = _tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(defaultTargetPlatform == TargetPlatform.iOS ? 0.48 : 0.47);
      await tts.setVolume(1);
      // Android: speak on the navigation-guidance stream, which plays with the ringer on silent.
      if (defaultTargetPlatform == TargetPlatform.android) await tts.setAudioAttributesForNavigation();
      return _ttsWorks = true;
    } catch (_) {
      return _ttsWorks = false;
    }
  }

  /// Points the engine at [l]'s voice, or English when the phone has none for it.
  static Future<void> _useLanguage(Lang l) async {
    if (_voiceFor == l) return;
    final tts = _tts!;
    _native = false;
    for (final tag in l.speech) {
      if (await tts.isLanguageAvailable(tag) == true) {
        await tts.setLanguage(tag);
        _native = true;
        break;
      }
    }
    if (!_native) {
      // Nigerian English when the phone has it, else British, else whatever it has.
      for (final tag in Lang.en.speech) {
        if (await tts.isLanguageAvailable(tag) == true) {
          await tts.setLanguage(tag);
          break;
        }
      }
    }
    _voiceFor = l;
  }

  static Future<void> _play(String clip) async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.alarm,
            contentType: AndroidContentType.speech,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: const {AVAudioSessionOptions.duckOthers}),
        ),
      );
      await p.stop();
      await p.play(AssetSource(clip), volume: 1);
      // Hold the queue until this clip finishes.
      await p.onPlayerComplete.first.timeout(const Duration(seconds: 6), onTimeout: () {});
    } catch (_) {}
  }
}
