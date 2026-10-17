import '../../core/util/rng.dart';

class SudokuPuzzle {
  SudokuPuzzle({required this.givens, required this.solution});

  /// 81 digits, 0 = empty.
  final List<int> givens;
  final List<int> solution;

  factory SudokuPuzzle.fromJson(Map<String, dynamic> j) =>
      SudokuPuzzle(givens: _digits(j['givens'] as String), solution: _digits(j['solution'] as String));

  Map<String, dynamic> toJson() => {'givens': givens.join(), 'solution': solution.join()};

  static List<int> _digits(String s) => [for (final ch in s.codeUnits) ch - 48];
}

class SudokuLogic {
  static int box(int i) => (i ~/ 27) * 3 + (i % 9) ~/ 3;

  /// Contract validation (docs/CONTRACT.md §3 SUDOKU).
  static bool isValidSolution(List<int> givens, List<int> grid) {
    if (grid.length != 81) return false;
    for (var i = 0; i < 81; i++) {
      if (grid[i] < 1 || grid[i] > 9) return false;
      if (givens[i] != 0 && givens[i] != grid[i]) return false;
    }
    for (var k = 0; k < 9; k++) {
      var row = 0, col = 0, bx = 0;
      for (var j = 0; j < 9; j++) {
        row |= 1 << grid[k * 9 + j];
        col |= 1 << grid[j * 9 + k];
        bx |= 1 << grid[(k ~/ 3) * 27 + (k % 3) * 3 + (j ~/ 3) * 9 + j % 3];
      }
      if (row != 0x3FE || col != 0x3FE || bx != 0x3FE) return false;
    }
    return true;
  }

  /// Bitmask backtracking solver with MRV. Counts solutions up to [limit].
  static int countSolutions(List<int> grid, {int limit = 2, List<int>? out}) {
    final g = List<int>.of(grid);
    final rows = List<int>.filled(9, 0), cols = List<int>.filled(9, 0), boxes = List<int>.filled(9, 0);
    for (var i = 0; i < 81; i++) {
      final v = g[i];
      if (v == 0) continue;
      final bit = 1 << v;
      if ((rows[i ~/ 9] | cols[i % 9] | boxes[box(i)]) & bit != 0) return 0;
      rows[i ~/ 9] |= bit;
      cols[i % 9] |= bit;
      boxes[box(i)] |= bit;
    }
    var count = 0;

    bool rec() {
      var best = -1, bestMask = 0, bestCount = 10;
      for (var i = 0; i < 81; i++) {
        if (g[i] != 0) continue;
        final mask = ~(rows[i ~/ 9] | cols[i % 9] | boxes[box(i)]) & 0x3FE;
        final n = _bits(mask);
        if (n < bestCount) {
          best = i;
          bestMask = mask;
          bestCount = n;
          if (n <= 1) break;
        }
      }
      if (best == -1) {
        count++;
        if (out != null && count == 1) {
          out
            ..clear()
            ..addAll(g);
        }
        return count >= limit;
      }
      if (bestCount == 0) return false;
      final r = best ~/ 9, c = best % 9, b = box(best);
      for (var v = 1; v <= 9; v++) {
        final bit = 1 << v;
        if (bestMask & bit == 0) continue;
        g[best] = v;
        rows[r] |= bit;
        cols[c] |= bit;
        boxes[b] |= bit;
        if (rec()) return true;
        rows[r] &= ~bit;
        cols[c] &= ~bit;
        boxes[b] &= ~bit;
        g[best] = 0;
      }
      return false;
    }

    rec();
    return count;
  }

  static int _bits(int m) {
    var n = 0;
    while (m != 0) {
      m &= m - 1;
      n++;
    }
    return n;
  }

  static List<int> _fullGrid(Rng rng) {
    final g = List<int>.filled(81, 0);
    bool fill(int i) {
      if (i == 81) return true;
      final digits = [1, 2, 3, 4, 5, 6, 7, 8, 9];
      rng.shuffle(digits);
      for (final d in digits) {
        if (_canPlace(g, i, d)) {
          g[i] = d;
          if (fill(i + 1)) return true;
          g[i] = 0;
        }
      }
      return false;
    }

    fill(0);
    return g;
  }

  static bool _canPlace(List<int> g, int i, int d) {
    final r = i ~/ 9, c = i % 9, b = box(i);
    for (var k = 0; k < 9; k++) {
      if (g[r * 9 + k] == d || g[k * 9 + c] == d) return false;
      if (g[(b ~/ 3) * 27 + (b % 3) * 3 + (k ~/ 3) * 9 + k % 3] == d) return false;
    }
    return true;
  }

  /// Generates a uniquely-solvable puzzle with roughly [targetGivens] clues.
  /// Cells are removed in symmetric pairs for a pleasing layout.
  static SudokuPuzzle generate(int targetGivens, int seed) {
    final rng = Rng(seed);
    final solution = _fullGrid(rng);
    final puzzle = List<int>.of(solution);
    final order = List<int>.generate(41, (i) => i);
    rng.shuffle(order);
    var givens = 81;
    for (final i in order) {
      if (givens <= targetGivens) break;
      final j = 80 - i;
      final a = puzzle[i], b = puzzle[j];
      puzzle[i] = 0;
      puzzle[j] = 0;
      if (countSolutions(puzzle) != 1) {
        puzzle[i] = a;
        puzzle[j] = b;
      } else {
        givens -= i == j ? 1 : 2;
      }
    }
    return SudokuPuzzle(givens: puzzle, solution: solution);
  }
}

/// Mutable play state for Sudoku with notes, undo and mistake tracking.
class SudokuBoard {
  SudokuBoard(this.puzzle) : values = List.of(puzzle.givens), notes = List.generate(81, (_) => <int>{});

  final SudokuPuzzle puzzle;
  final List<int> values;
  final List<Set<int>> notes;
  final List<(List<int>, List<Set<int>>)> _history = [];
  int mistakes = 0;

  bool isGiven(int i) => puzzle.givens[i] != 0;
  bool get canUndo => _history.isNotEmpty;

  void _snapshot() {
    _history.add((List.of(values), [for (final n in notes) Set.of(n)]));
    if (_history.length > 300) _history.removeAt(0);
  }

  void undo() {
    if (_history.isEmpty) return;
    final (v, n) = _history.removeLast();
    for (var i = 0; i < 81; i++) {
      values[i] = v[i];
      notes[i] = n[i];
    }
  }

  /// Returns true if the entry is correct.
  bool enter(int i, int d) {
    if (isGiven(i)) return true;
    _snapshot();
    values[i] = d;
    notes[i].clear();
    final ok = puzzle.solution[i] == d;
    if (ok) {
      // Clear this digit from notes of peers.
      final r = i ~/ 9, c = i % 9, b = SudokuLogic.box(i);
      for (var k = 0; k < 81; k++) {
        if (k ~/ 9 == r || k % 9 == c || SudokuLogic.box(k) == b) notes[k].remove(d);
      }
    } else {
      mistakes++;
    }
    return ok;
  }

  void toggleNote(int i, int d) {
    if (isGiven(i) || values[i] != 0) return;
    _snapshot();
    if (!notes[i].remove(d)) notes[i].add(d);
  }

  void erase(int i) {
    if (isGiven(i)) return;
    _snapshot();
    values[i] = 0;
    notes[i].clear();
  }

  /// Reveals a correct digit in the most constrained empty/wrong cell.
  int? hint() {
    int? target;
    for (var i = 0; i < 81; i++) {
      if (values[i] != puzzle.solution[i]) {
        target = i;
        break;
      }
    }
    if (target == null) return null;
    _snapshot();
    values[target] = puzzle.solution[target];
    notes[target].clear();
    return target;
  }

  bool get solved {
    for (var i = 0; i < 81; i++) {
      if (values[i] != puzzle.solution[i]) return false;
    }
    return true;
  }

  int remainingOf(int d) => 9 - values.asMap().entries.where((e) => e.value == d && puzzle.solution[e.key] == d).length;
}
