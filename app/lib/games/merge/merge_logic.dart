import '../../core/util/rng.dart';

enum MoveDir { left, right, up, down }

extension MoveDirX on MoveDir {
  String get code => switch (this) {
    MoveDir.left => 'L',
    MoveDir.right => 'R',
    MoveDir.up => 'U',
    MoveDir.down => 'D',
  };
}

class MergePuzzle {
  MergePuzzle({required this.seed, required this.target, this.size = 4});
  final int size;
  final int seed;
  final int target;

  factory MergePuzzle.fromJson(Map<String, dynamic> j) =>
      MergePuzzle(size: j['size'] as int? ?? 4, seed: j['seed'] as int, target: j['target'] as int);

  Map<String, dynamic> toJson() => {'size': size, 'seed': seed, 'target': target};
}

/// A tile with a stable identity so the UI can animate slides and merges.
class Tile {
  Tile(this.id, this.value, this.row, this.col);
  final int id;
  int value;
  int row, col;
  bool mergedThisMove = false;
  bool spawnedThisMove = true;
  // Tile that was absorbed into this one during the last move (for the slide animation).
  Tile? absorbed;
}

/// Seeded 2048-style engine. Behaviour is specified in docs/CONTRACT.md §3 MERGE and
/// replayed identically on the server for daily leaderboards.
class MergeGame {
  MergeGame(this.puzzle) : _rng = Rng(puzzle.seed) {
    _spawn();
    _spawn();
  }

  final MergePuzzle puzzle;
  final Rng _rng;
  final List<Tile> tiles = [];
  final List<Tile> removed = [];
  final StringBuffer moves = StringBuffer();
  int score = 0;
  int _nextId = 1;
  int moveCount = 0;

  int get size => puzzle.size;

  int get maxTile => tiles.fold(0, (m, t) => t.value > m ? t.value : m);
  bool get won => maxTile >= puzzle.target;

  Tile? at(int r, int c) {
    for (final t in tiles) {
      if (t.row == r && t.col == c) return t;
    }
    return null;
  }

  List<int> get grid {
    final g = List<int>.filled(size * size, 0);
    for (final t in tiles) {
      g[t.row * size + t.col] = t.value;
    }
    return g;
  }

  void _spawn() {
    final empties = <int>[];
    final g = grid;
    for (var i = 0; i < g.length; i++) {
      if (g[i] == 0) empties.add(i);
    }
    if (empties.isEmpty) return;
    final idx = empties[_rng.nextInt(empties.length)];
    final value = _rng.nextInt(10) == 0 ? 4 : 2;
    tiles.add(Tile(_nextId++, value, idx ~/ size, idx % size));
  }

  /// Applies a move. Returns false (and changes nothing) if the move is a no-op.
  bool move(MoveDir dir) {
    for (final t in tiles) {
      t.mergedThisMove = false;
      t.spawnedThisMove = false;
      t.absorbed = null;
    }
    removed.clear();
    var changed = false;
    for (var line = 0; line < size; line++) {
      // Cells ordered from the wall we slide towards.
      final cells = <(int, int)>[
        for (var k = 0; k < size; k++)
          switch (dir) {
            MoveDir.left => (line, k),
            MoveDir.right => (line, size - 1 - k),
            MoveDir.up => (k, line),
            MoveDir.down => (size - 1 - k, line),
          },
      ];
      final lineTiles = [for (final (r, c) in cells) at(r, c)].whereType<Tile>().toList();
      var slot = 0;
      Tile? last;
      for (final t in lineTiles) {
        if (last != null && !last.mergedThisMove && last.value == t.value) {
          last.value *= 2;
          last.mergedThisMove = true;
          last.absorbed = t;
          score += last.value;
          final (r, c) = cells[slot - 1];
          t.row = r;
          t.col = c;
          tiles.remove(t);
          removed.add(t);
          changed = true;
          continue;
        }
        final (r, c) = cells[slot];
        if (t.row != r || t.col != c) changed = true;
        t.row = r;
        t.col = c;
        last = t;
        slot++;
      }
    }
    if (!changed) return false;
    moves.write(dir.code);
    moveCount++;
    _spawn();
    return true;
  }

  bool get canMove {
    if (tiles.length < size * size) return true;
    final g = grid;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = g[r * size + c];
        if (c + 1 < size && g[r * size + c + 1] == v) return true;
        if (r + 1 < size && g[(r + 1) * size + c] == v) return true;
      }
    }
    return false;
  }

  /// Replays a move string from scratch (used by tests to mirror the server).
  static MergeGame replay(MergePuzzle p, String moveString) {
    final g = MergeGame(p);
    for (final ch in moveString.split('')) {
      final dir = switch (ch) {
        'L' => MoveDir.left,
        'R' => MoveDir.right,
        'U' => MoveDir.up,
        _ => MoveDir.down,
      };
      g.move(dir);
      if (!g.canMove) break;
    }
    return g;
  }
}
