import '../../core/util/rng.dart';

class LadderPuzzle {
  LadderPuzzle({required this.start, required this.target, required this.par});
  final String start;
  final String target;
  final int par;

  factory LadderPuzzle.fromJson(Map<String, dynamic> j) =>
      LadderPuzzle(start: j['start'] as String, target: j['target'] as String, par: j['par'] as int);

  Map<String, dynamic> toJson() => {'start': start, 'target': target, 'par': par};
}

/// Word graph over content/words4.txt (shared with the backend).
class LadderDictionary {
  LadderDictionary(Iterable<String> words) : words = words.map((w) => w.trim().toUpperCase()).where((w) => w.length == 4).toSet() {
    sorted = this.words.toList()..sort();
  }

  final Set<String> words;
  late final List<String> sorted;

  bool contains(String w) => words.contains(w.toUpperCase());

  static bool oneApart(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      if (a.codeUnitAt(i) != b.codeUnitAt(i) && ++diff > 1) return false;
    }
    return diff == 1;
  }

  Iterable<String> neighbours(String w) sync* {
    for (var i = 0; i < w.length; i++) {
      for (var c = 65; c <= 90; c++) {
        if (c == w.codeUnitAt(i)) continue;
        final cand = w.substring(0, i) + String.fromCharCode(c) + w.substring(i + 1);
        if (words.contains(cand)) yield cand;
      }
    }
  }

  /// BFS distances from [start].
  Map<String, int> distances(String start) {
    final d = <String, int>{start: 0};
    final q = <String>[start];
    var head = 0;
    while (head < q.length) {
      final x = q[head++];
      for (final y in neighbours(x)) {
        if (!d.containsKey(y)) {
          d[y] = d[x]! + 1;
          q.add(y);
        }
      }
    }
    return d;
  }

  /// Shortest path (inclusive) from a to b, or null.
  List<String>? shortestPath(String a, String b) {
    final prev = <String, String?>{a: null};
    final q = <String>[a];
    var head = 0;
    while (head < q.length) {
      final x = q[head++];
      if (x == b) break;
      for (final y in neighbours(x)) {
        if (!prev.containsKey(y)) {
          prev[y] = x;
          q.add(y);
        }
      }
    }
    if (!prev.containsKey(b)) return null;
    final path = <String>[];
    String? cur = b;
    while (cur != null) {
      path.add(cur);
      cur = prev[cur];
    }
    return path.reversed.toList();
  }

  LadderPuzzle generate(int par, int seed) {
    final rng = Rng(seed);
    for (var attempt = 0; attempt < 200; attempt++) {
      final start = sorted[rng.nextInt(sorted.length)];
      final d = distances(start);
      final candidates = d.entries.where((e) => e.value == par).map((e) => e.key).toList()..sort();
      if (candidates.isEmpty) continue;
      final target = candidates[rng.nextInt(candidates.length)];
      return LadderPuzzle(start: start, target: target, par: par);
    }
    throw StateError('No ladder of par $par for seed $seed');
  }

  /// Contract validation (docs/CONTRACT.md §3 LADDER).
  bool isValidPath(LadderPuzzle p, List<String> path) {
    if (path.length < 2 || path.first != p.start || path.last != p.target) return false;
    for (var i = 0; i < path.length; i++) {
      if (!contains(path[i])) return false;
      if (i > 0 && !oneApart(path[i - 1], path[i])) return false;
    }
    return true;
  }
}
