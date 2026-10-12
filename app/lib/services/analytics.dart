import 'package:flutter/foundation.dart';

/// Product analytics facade (docs spec 02 "North-star metrics and event plan").
///
/// Events are deliberately small and contain no personal data. Wire a sink such as
/// Firebase Analytics by implementing [AnalyticsSink] and passing it in main().
abstract class AnalyticsSink {
  void log(String event, Map<String, Object> params);
}

class DebugAnalyticsSink implements AnalyticsSink {
  @override
  void log(String event, Map<String, Object> params) => debugPrint('[analytics] $event $params');
}

class Analytics {
  Analytics([List<AnalyticsSink>? sinks]) : _sinks = sinks ?? [if (kDebugMode) DebugAnalyticsSink()];
  final List<AnalyticsSink> _sinks;

  final DateTime _launch = DateTime.now();
  bool _firstFunLogged = false;

  void log(String event, [Map<String, Object> params = const {}]) {
    for (final s in _sinks) {
      try {
        s.log(event, params);
      } catch (_) {}
    }
  }

  void puzzleStart(String game, String source, String difficulty) =>
      log('puzzle_start', {'game': game, 'source': source, 'difficulty': difficulty});

  void puzzleComplete(String game, String source, {required bool won, required int ms, required int hints}) {
    log('puzzle_complete', {'game': game, 'source': source, 'won': won, 'ms': ms, 'hints': hints});
    if (won && !_firstFunLogged) {
      _firstFunLogged = true;
      log('time_to_first_win', {'ms': DateTime.now().difference(_launch).inMilliseconds});
    }
  }
}
