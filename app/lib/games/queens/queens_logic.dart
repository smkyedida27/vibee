import '../../core/util/rng.dart';

/// A Crowns (queens-style) puzzle: N×N grid split into N colour regions.
class QueensPuzzle {
  QueensPuzzle({required this.size, required this.regions, required this.solution});

  final int size;

  /// regions[row][col] = region index 0..size-1.
  final List<List<int>> regions;

  /// solution[row] = column of the crown in that row.
  final List<int> solution;

  factory QueensPuzzle.fromJson(Map<String, dynamic> j) => QueensPuzzle(
        size: j['size'] as int,
        regions: [for (final r in j['regions'] as List) (r as List).cast<int>()],
        solution: (j['solution'] as List).cast<int>(),
      );

  Map<String, dynamic> toJson() => {'size': size, 'regions': regions, 'solution': solution};
}

class QueensLogic {
  /// Contract validation (docs/CONTRACT.md §3 QUEENS).
  static bool isValidSolution(QueensPuzzle p, List<int> queens) {
    if (queens.length != p.size) return false;
    final cols = <int>{}, regs = <int>{};
    for (var r = 0; r < p.size; r++) {
      final c = queens[r];
      if (c < 0 || c >= p.size) return false;
      if (!cols.add(c)) return false;
      if (!regs.add(p.regions[r][c])) return false;
      if (r > 0 && (queens[r - 1] - c).abs() <= 1) return false;
    }
    return true;
  }

  /// Counts solutions up to [limit].
  static int countSolutions(List<List<int>> regions, int size, {int limit = 2, List<int>? first}) {
    var count = 0;
    final cols = List<bool>.filled(size, false);
    final regs = List<bool>.filled(size, false);
    final placed = List<int>.filled(size, -1);

    bool rec(int r) {
      if (r == size) {
        count++;
        if (count == 1 && first != null) {
          first
            ..clear()
            ..addAll(placed);
        }
        return count >= limit;
      }
      for (var c = 0; c < size; c++) {
        if (cols[c]) continue;
        final reg = regions[r][c];
        if (regs[reg]) continue;
        if (r > 0 && (placed[r - 1] - c).abs() <= 1) continue;
        cols[c] = true;
        regs[reg] = true;
        placed[r] = c;
        if (rec(r + 1)) return true;
        cols[c] = false;
        regs[reg] = false;
      }
      return false;
    }

    rec(0);
    return count;
  }

  /// Generates a puzzle with exactly one solution. Deterministic for a given seed.
  ///
  /// Regions are grown from a random crown layout, then repaired: while another
  /// solution exists, a cell used by that rival solution is handed to a
  /// neighbouring region (keeping every region contiguous), which kills it.
  static QueensPuzzle generate(int size, int seed) {
    final rng = Rng(seed);
    for (var attempt = 0; attempt < 400; attempt++) {
      final queens = _randomPlacement(size, rng);
      if (queens == null) continue;
      final regions = _growRegions(size, queens, rng);
      for (var step = 0; step < size * size * 3; step++) {
        final rival = _otherSolution(regions, size, queens);
        if (rival == null) {
          return QueensPuzzle(size: size, regions: regions, solution: queens);
        }
        if (!_breakRival(regions, size, queens, rival, rng)) break;
      }
    }
    throw StateError('Could not generate unique $size×$size Crowns puzzle for seed $seed');
  }

  /// First solution that differs from [intended], or null if [intended] is unique.
  static List<int>? _otherSolution(List<List<int>> regions, int size, List<int> intended) {
    List<int>? found;
    final cols = List<bool>.filled(size, false);
    final regs = List<bool>.filled(size, false);
    final placed = List<int>.filled(size, -1);
    bool rec(int r) {
      if (r == size) {
        for (var i = 0; i < size; i++) {
          if (placed[i] != intended[i]) {
            found = List.of(placed);
            return true;
          }
        }
        return false;
      }
      for (var c = 0; c < size; c++) {
        if (cols[c]) continue;
        final reg = regions[r][c];
        if (regs[reg]) continue;
        if (r > 0 && (placed[r - 1] - c).abs() <= 1) continue;
        cols[c] = true;
        regs[reg] = true;
        placed[r] = c;
        if (rec(r + 1)) return true;
        cols[c] = false;
        regs[reg] = false;
      }
      return false;
    }

    rec(0);
    return found;
  }

  static const _dirs = [
    [0, 1],
    [1, 0],
    [0, -1],
    [-1, 0]
  ];

  static bool _breakRival(List<List<int>> g, int n, List<int> queens, List<int> rival, Rng rng) {
    final rows = [for (var r = 0; r < n; r++) if (rival[r] != queens[r]) r];
    rng.shuffle(rows);
    for (final r in rows) {
      final c = rival[r];
      final from = g[r][c];
      final options = <int>{};
      for (final d in _dirs) {
        final rr = r + d[0], cc = c + d[1];
        if (rr < 0 || cc < 0 || rr >= n || cc >= n) continue;
        if (g[rr][cc] != from) options.add(g[rr][cc]);
      }
      if (options.isEmpty) continue;
      g[r][c] = -1;
      if (!_connected(g, n, from)) {
        g[r][c] = from;
        continue;
      }
      final list = options.toList()..sort();
      g[r][c] = list[rng.nextInt(list.length)];
      return true;
    }
    return false;
  }

  static bool _connected(List<List<int>> g, int n, int reg) {
    final cells = <int>[];
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (g[r][c] == reg) cells.add(r * n + c);
      }
    }
    if (cells.isEmpty) return false;
    final seen = <int>{cells.first};
    final q = [cells.first];
    while (q.isNotEmpty) {
      final x = q.removeLast();
      for (final d in _dirs) {
        final rr = x ~/ n + d[0], cc = x % n + d[1];
        if (rr < 0 || cc < 0 || rr >= n || cc >= n) continue;
        final k = rr * n + cc;
        if (g[rr][cc] == reg && seen.add(k)) q.add(k);
      }
    }
    return seen.length == cells.length;
  }

  static List<int>? _randomPlacement(int n, Rng rng) {
    final cols = List<int>.filled(n, -1);
    final used = List<bool>.filled(n, false);
    bool rec(int r) {
      if (r == n) return true;
      final order = List<int>.generate(n, (i) => i);
      rng.shuffle(order);
      for (final c in order) {
        if (used[c]) continue;
        if (r > 0 && (cols[r - 1] - c).abs() <= 1) continue;
        used[c] = true;
        cols[r] = c;
        if (rec(r + 1)) return true;
        used[c] = false;
      }
      return false;
    }

    return rec(0) ? cols : null;
  }

  /// Grows N contiguous regions outward from the crown cells. Growth is biased
  /// towards smaller regions so shapes stay varied but balanced.
  static List<List<int>> _growRegions(int n, List<int> queens, Rng rng) {
    final g = List.generate(n, (_) => List<int>.filled(n, -1));
    final sizes = List<int>.filled(n, 1);
    for (var r = 0; r < n; r++) {
      g[r][queens[r]] = r;
    }
    var remaining = n * n - n;
    const dirs = _dirs;
    while (remaining > 0) {
      // Collect frontier (unassigned cell, neighbouring region).
      final frontier = <List<int>>[];
      for (var r = 0; r < n; r++) {
        for (var c = 0; c < n; c++) {
          if (g[r][c] != -1) continue;
          for (final d in dirs) {
            final rr = r + d[0], cc = c + d[1];
            if (rr < 0 || cc < 0 || rr >= n || cc >= n) continue;
            final reg = g[rr][cc];
            if (reg != -1) frontier.add([r, c, reg]);
          }
        }
      }
      // Weighted pick: prefer small regions (weight = 1 / size^1.5 approximated with ints).
      var total = 0;
      final weights = <int>[];
      for (final f in frontier) {
        final s = sizes[f[2]];
        final w = 1000 ~/ (s * s) + 1 + rng.nextInt(40);
        weights.add(w);
        total += w;
      }
      var pick = rng.nextInt(total);
      var i = 0;
      while (pick >= weights[i]) {
        pick -= weights[i];
        i++;
      }
      final f = frontier[i];
      g[f[0]][f[1]] = f[2];
      sizes[f[2]]++;
      remaining--;
    }
    return g;
  }
}

/// Player-facing board state for Crowns.
enum QueenMark { empty, cross, crown }

class QueensBoard {
  QueensBoard(this.puzzle) : marks = List.generate(puzzle.size, (_) => List.filled(puzzle.size, QueenMark.empty));

  final QueensPuzzle puzzle;
  final List<List<QueenMark>> marks;
  final List<List<List<QueenMark>>> _history = [];

  int get size => puzzle.size;

  void _snapshot() {
    _history.add([for (final row in marks) List.of(row)]);
    if (_history.length > 200) _history.removeAt(0);
  }

  bool get canUndo => _history.isNotEmpty;

  void undo() {
    if (_history.isEmpty) return;
    final prev = _history.removeLast();
    for (var r = 0; r < size; r++) {
      marks[r] = prev[r];
    }
  }

  void cycle(int r, int c) {
    _snapshot();
    marks[r][c] = switch (marks[r][c]) {
      QueenMark.empty => QueenMark.cross,
      QueenMark.cross => QueenMark.crown,
      QueenMark.crown => QueenMark.empty,
    };
  }

  void set(int r, int c, QueenMark m) {
    if (marks[r][c] == m) return;
    _snapshot();
    marks[r][c] = m;
  }

  void reset() {
    _snapshot();
    for (final row in marks) {
      row.fillRange(0, size, QueenMark.empty);
    }
  }

  List<(int, int)> get crowns => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++)
            if (marks[r][c] == QueenMark.crown) (r, c)
      ];

  /// Cells whose crown conflicts with another crown (same row/col/region or touching).
  Set<(int, int)> conflicts() {
    final cs = crowns;
    final bad = <(int, int)>{};
    for (var i = 0; i < cs.length; i++) {
      for (var j = i + 1; j < cs.length; j++) {
        final a = cs[i], b = cs[j];
        final touching = (a.$1 - b.$1).abs() <= 1 && (a.$2 - b.$2).abs() <= 1;
        if (a.$1 == b.$1 ||
            a.$2 == b.$2 ||
            puzzle.regions[a.$1][a.$2] == puzzle.regions[b.$1][b.$2] ||
            touching) {
          bad
            ..add(a)
            ..add(b);
        }
      }
    }
    return bad;
  }

  bool get solved {
    final cs = crowns;
    if (cs.length != size) return false;
    final perRow = List<int>.filled(size, -1);
    for (final c in cs) {
      if (perRow[c.$1] != -1) return false;
      perRow[c.$1] = c.$2;
    }
    return QueensLogic.isValidSolution(puzzle, perRow);
  }

  List<int> get submission {
    final perRow = List<int>.filled(size, -1);
    for (final c in crowns) {
      perRow[c.$1] = c.$2;
    }
    return perRow;
  }

  /// Hint: reveal one correct crown not yet placed (clearing anything blocking it).
  (int, int)? hint() {
    for (var r = 0; r < size; r++) {
      final c = puzzle.solution[r];
      if (marks[r][c] != QueenMark.crown) {
        _snapshot();
        // Remove wrong crowns in this row.
        for (var cc = 0; cc < size; cc++) {
          if (marks[r][cc] == QueenMark.crown) marks[r][cc] = QueenMark.empty;
        }
        marks[r][c] = QueenMark.crown;
        return (r, c);
      }
    }
    return null;
  }

  /// Auto-cross every cell that can no longer hold a crown (row/col/region/touching).
  void autoCross() {
    _snapshot();
    for (final (qr, qc) in crowns) {
      final reg = puzzle.regions[qr][qc];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (r == qr && c == qc) continue;
          final hit = r == qr || c == qc || puzzle.regions[r][c] == reg || ((r - qr).abs() <= 1 && (c - qc).abs() <= 1);
          if (hit && marks[r][c] == QueenMark.empty) marks[r][c] = QueenMark.cross;
        }
      }
    }
  }
}
