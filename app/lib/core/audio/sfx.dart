import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum Sfx { tap, pop, select, wrong, success, star, coin, win, lose, whoosh, merge, unlock }

/// Low-latency sound effects + haptics. Synthesised WAVs live in assets/sfx.
/// Settings toggles are pushed in from PlayerState.
class Audio {
  Audio._();
  static final Audio instance = Audio._();

  bool soundOn = true;
  bool hapticsOn = true;
  final Map<Sfx, AudioPool> _pools = {};
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    for (final s in Sfx.values) {
      try {
        _pools[s] = await AudioPool.createFromAsset(path: 'sfx/${s.name}.wav', maxPlayers: 3);
      } catch (e) {
        debugPrint('sfx ${s.name} unavailable: $e');
      }
    }
  }

  void play(Sfx s, {double volume = 0.8}) {
    if (!soundOn) return;
    final pool = _pools[s];
    if (pool == null) return;
    pool.start(volume: volume).then((_) {}, onError: (Object e) => debugPrint('sfx error: $e'));
  }

  void haptic([HapticKind kind = HapticKind.light]) {
    if (!hapticsOn) return;
    switch (kind) {
      case HapticKind.light:
        HapticFeedback.lightImpact();
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
      case HapticKind.select:
        HapticFeedback.selectionClick();
    }
  }

  void fx(Sfx s, [HapticKind kind = HapticKind.light]) {
    play(s);
    haptic(kind);
  }
}

enum HapticKind { light, medium, heavy, select }
