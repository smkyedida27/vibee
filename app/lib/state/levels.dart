import 'package:flutter/material.dart';

import '../core/util/rng.dart';
import '../games/common/game_type.dart';

/// A themed episode on the saga map.
class World {
  const World(this.name, this.top, this.bottom, this.accent, this.path);
  final String name;
  final Color top, bottom, accent, path;
}

class LevelSpec {
  LevelSpec({
    required this.number,
    required this.game,
    required this.difficulty,
    required this.seed,
    required this.boss,
  });
  final int number;
  final GameType game;
  final Difficulty difficulty;
  final int seed;

  /// Every 10th level is a "boss" level: harder, bigger reward, special node art.
  final bool boss;
}

/// Procedural campaign: endless levels across themed worlds with a gentle
/// difficulty ramp and game rotation that keeps sessions varied.
class Campaign {
  static const levelsPerWorld = 20;
  static const totalLevels = 600;

  static const worlds = <World>[
    World('Candy Meadow', Color(0xFF7BE495), Color(0xFF2FB5A8), Color(0xFFFF5FA2), Color(0xFFFFF4D6)),
    World('Lollipop Lagoon', Color(0xFF6FD6FF), Color(0xFF3A6FF7), Color(0xFFFFC21A), Color(0xFFE6F7FF)),
    World('Marshmallow Peaks', Color(0xFFD6C2FF), Color(0xFF8E5CF7), Color(0xFF14C8C0), Color(0xFFFFFFFF)),
    World('Caramel Canyon', Color(0xFFFFC58A), Color(0xFFE2622C), Color(0xFF9B4DFF), Color(0xFFFFEBD1)),
    World('Bubblegum Bay', Color(0xFFFFA8D5), Color(0xFFD9338F), Color(0xFF22D36B), Color(0xFFFFE6F3)),
    World('Frosty Fudge', Color(0xFFBDEBFF), Color(0xFF4F8FD8), Color(0xFFFF7A1A), Color(0xFFF2FBFF)),
    World('Starlight Sweets', Color(0xFF7A5CFF), Color(0xFF241A6B), Color(0xFFFFE066), Color(0xFFE9E3FF)),
    World('Jelly Jungle', Color(0xFFA6F07A), Color(0xFF2E8F4A), Color(0xFFFF3D7F), Color(0xFFF1FFE6)),
  ];

  static World worldOf(int level) => worlds[((level - 1) ~/ levelsPerWorld) % worlds.length];
  static int worldIndex(int level) => (level - 1) ~/ levelsPerWorld;

  static const _intro = [GameType.connect, GameType.queens, GameType.merge, GameType.ladder, GameType.sudoku];
  static const _cycle = [
    GameType.queens,
    GameType.connect,
    GameType.merge,
    GameType.ladder,
    GameType.sudoku,
    GameType.queens,
    GameType.ladder,
    GameType.merge,
    GameType.connect,
    GameType.sudoku,
  ];

  static LevelSpec level(int n) {
    final game = n <= _intro.length ? _intro[n - 1] : _cycle[(n - _intro.length - 1) % _cycle.length];
    final boss = n % 10 == 0;
    final w = worldIndex(n);
    var tier = switch (w) {
      0 => 0,
      1 => n % 4 == 0 ? 1 : 0,
      2 => 1,
      3 => n % 3 == 0 ? 2 : 1,
      4 || 5 => 2,
      _ => 3,
    };
    if (boss) tier = (tier + 1).clamp(0, 3);
    return LevelSpec(
      number: n,
      game: game,
      difficulty: Difficulty.values[tier],
      seed: fnv1a('puzzlehub-level-$n'),
      boss: boss,
    );
  }

  // Per-game tuning by difficulty.
  static int queensSize(Difficulty d, int seed) => switch (d) {
    Difficulty.easy => 5 + seed % 2,
    Difficulty.medium => 7,
    Difficulty.hard => 8,
    Difficulty.expert => 9,
  };

  static int sudokuGivens(Difficulty d) => switch (d) {
    Difficulty.easy => 42,
    Difficulty.medium => 34,
    Difficulty.hard => 29,
    Difficulty.expert => 25,
  };

  static int ladderPar(Difficulty d) => switch (d) {
    Difficulty.easy => 3,
    Difficulty.medium => 4,
    Difficulty.hard => 5,
    Difficulty.expert => 6,
  };

  static int mergeTarget(Difficulty d) => switch (d) {
    Difficulty.easy => 128,
    Difficulty.medium => 256,
    Difficulty.hard => 512,
    Difficulty.expert => 1024,
  };
}
