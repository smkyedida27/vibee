import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/util/rng.dart';
import '../games/common/game_type.dart';
import '../games/connect/connect_logic.dart';
import '../games/ladder/ladder_logic.dart';
import '../games/merge/merge_logic.dart';
import '../games/queens/queens_logic.dart';
import '../games/sudoku/sudoku_logic.dart';
import '../state/levels.dart';
import '../state/player.dart';
import 'api_client.dart';

enum PlaySource { level, daily, quick }

/// Everything a game screen needs to start a round.
class PlayRequest {
  PlayRequest({
    required this.game,
    required this.difficulty,
    required this.source,
    required this.seed,
    this.level,
    this.daily,
    this.stage,
  });

  final GameType game;
  final Difficulty difficulty;
  final PlaySource source;
  final int seed;
  final int? level;
  final DailyPuzzle? daily;

  /// Level number inside the [game] × [difficulty] track (1-based), for track play.
  final int? stage;

  /// A fixed level in a difficulty track: the same puzzle for every player.
  factory PlayRequest.stage(GameType game, Difficulty difficulty, int n) => PlayRequest(
    game: game,
    difficulty: difficulty,
    source: PlaySource.quick,
    seed: (((game.index * 4 + difficulty.index) * 1000 + n) * 2654435761) & 0x7FFFFFFF,
    stage: n,
  );

  factory PlayRequest.level(int n) {
    final spec = Campaign.level(n);
    return PlayRequest(
      game: spec.game,
      difficulty: spec.difficulty,
      source: PlaySource.level,
      seed: spec.seed,
      level: n,
    );
  }

  String get title => switch (source) {
    PlaySource.level => 'Level $level',
    PlaySource.daily => 'Daily ${game.title}',
    PlaySource.quick => stage != null ? 'Level $stage' : game.title,
  };
}

/// A daily puzzle as served by `GET /daily-challenge` (or generated offline).
class DailyPuzzle {
  DailyPuzzle({
    required this.puzzleId,
    required this.game,
    required this.difficulty,
    required this.content,
    required this.date,
    this.offline = false,
  });

  final String? puzzleId;
  final GameType game;
  final Difficulty difficulty;
  final Map<String, dynamic> content;
  final String date;

  /// Offline fallbacks are playable for the streak but not leaderboard-eligible.
  final bool offline;
}

class DailySet {
  DailySet(this.date, this.puzzles, {this.offline = false});
  final String date;
  final Map<GameType, DailyPuzzle> puzzles;
  final bool offline;
}

// Top-level so they can run in a background isolate via compute().
Map<String, dynamic> _genQueens(List<int> a) => QueensLogic.generate(a[0], a[1]).toJson();
Map<String, dynamic> _genSudoku(List<int> a) => SudokuLogic.generate(a[0], a[1]).toJson();

class ContentRepo {
  ContentRepo(this._prefs, this._api);
  final SharedPreferences _prefs;
  final ApiClient _api;

  late final List<ConnectPuzzle> connectPuzzles;
  late final LadderDictionary dictionary;
  bool _loaded = false;

  Future<void> init() async {
    if (_loaded) return;
    final connect = jsonDecode(await rootBundle.loadString('assets/content/connect.json')) as Map<String, dynamic>;
    connectPuzzles = [for (final p in connect['puzzles'] as List) ConnectPuzzle.fromJson(p as Map<String, dynamic>)];
    dictionary = LadderDictionary(
      const LineSplitter().convert(await rootBundle.loadString('assets/content/words4.txt')),
    );
    _loaded = true;
  }

  /// Builds a typed puzzle (ConnectPuzzle / QueensPuzzle / SudokuPuzzle / LadderPuzzle / MergePuzzle).
  Future<Object> build(PlayRequest r) async {
    if (r.daily != null) return parse(r.game, r.daily!.content);
    final rng = Rng(r.seed);
    switch (r.game) {
      case GameType.connect:
        // Campaign walks the curated set in order; later loops reshuffle the tiles.
        final idx = r.level != null
            ? _connectIndexForLevel(r.level!)
            : r.stage != null
            // Each difficulty walks the curated set from a different starting point.
            ? r.stage! - 1 + r.difficulty.index * 7
            : rng.nextInt(connectPuzzles.length);
        final base = connectPuzzles[idx % connectPuzzles.length];
        final words = List.of(base.words);
        if ((r.level == null && r.stage == null) ||
            (r.level ?? 0) > connectPuzzles.length * 5 ||
            (r.stage ?? 0) > connectPuzzles.length) {
          rng.shuffle(words);
        }
        return ConnectPuzzle(id: base.id, words: words, groups: base.groups);
      case GameType.queens:
        final size = Campaign.queensSize(r.difficulty, r.seed);
        return QueensPuzzle.fromJson(await compute(_genQueens, [size, r.seed]));
      case GameType.sudoku:
        return SudokuPuzzle.fromJson(await compute(_genSudoku, [Campaign.sudokuGivens(r.difficulty), r.seed]));
      case GameType.ladder:
        return dictionary.generate(Campaign.ladderPar(r.difficulty), r.seed);
      case GameType.merge:
        return MergePuzzle(seed: r.seed, target: Campaign.mergeTarget(r.difficulty));
    }
  }

  int _connectIndexForLevel(int level) {
    // Count CONNECT levels up to this one so each appears once before repeating.
    var n = 0;
    for (var i = 1; i < level; i++) {
      if (Campaign.level(i).game == GameType.connect) n++;
    }
    return n;
  }

  Object parse(GameType g, Map<String, dynamic> content) => switch (g) {
    GameType.connect => ConnectPuzzle.fromJson(content),
    GameType.queens => QueensPuzzle.fromJson(content),
    GameType.sudoku => SudokuPuzzle.fromJson(content),
    GameType.ladder => LadderPuzzle.fromJson(content),
    GameType.merge => MergePuzzle.fromJson(content),
  };

  // ----------------------------------------------------------------- daily
  /// Today's set: network first, then today's cache, then a local offline set.
  Future<DailySet> daily() async {
    final today = utcDate();
    try {
      final j = await _api.dailyChallenge();
      await _prefs.setString('daily.cache', jsonEncode(j));
      return _parseDaily(j);
    } on ApiException catch (e) {
      debugPrint('daily fetch failed: $e');
    } catch (e) {
      debugPrint('daily parse failed: $e');
    }
    final cached = _prefs.getString('daily.cache');
    if (cached != null) {
      final j = jsonDecode(cached) as Map<String, dynamic>;
      if (j['date'] == today) return _parseDaily(j);
    }
    return _offlineDaily(today);
  }

  DailySet _parseDaily(Map<String, dynamic> j) {
    final date = j['date'] as String;
    final map = <GameType, DailyPuzzle>{};
    for (final p in j['puzzles'] as List) {
      final m = p as Map<String, dynamic>;
      final g = GameTypeX.fromWire(m['gameType'] as String);
      map[g] = DailyPuzzle(
        puzzleId: '${m['puzzleId']}',
        game: g,
        difficulty: DifficultyX.fromWire(m['difficulty'] as String),
        content: (m['content'] as Map).cast<String, dynamic>(),
        date: date,
      );
    }
    return DailySet(date, map);
  }

  Future<DailySet> _offlineDaily(String date) async {
    final map = <GameType, DailyPuzzle>{};
    for (final g in GameType.values) {
      final seed = fnv1a('offline-daily-$date-${g.wire}');
      final req = PlayRequest(game: g, difficulty: Difficulty.medium, source: PlaySource.quick, seed: seed);
      final puzzle = await build(req);
      final content = switch (puzzle) {
        ConnectPuzzle p => p.toJson(),
        QueensPuzzle p => p.toJson(),
        SudokuPuzzle p => p.toJson(),
        LadderPuzzle p => p.toJson(),
        MergePuzzle p => p.toJson(),
        _ => <String, dynamic>{},
      };
      map[g] = DailyPuzzle(
        puzzleId: null,
        game: g,
        difficulty: Difficulty.medium,
        content: content,
        date: date,
        offline: true,
      );
    }
    return DailySet(date, map, offline: true);
  }
}
