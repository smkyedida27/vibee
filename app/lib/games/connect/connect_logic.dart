class ConnectGroup {
  ConnectGroup({required this.title, required this.level, required this.words});
  final String title;
  final int level;
  final List<String> words;

  factory ConnectGroup.fromJson(Map<String, dynamic> j) =>
      ConnectGroup(title: j['title'] as String, level: j['level'] as int, words: (j['words'] as List).cast<String>());

  Map<String, dynamic> toJson() => {'title': title, 'level': level, 'words': words};
}

class ConnectPuzzle {
  ConnectPuzzle({required this.id, required this.words, required this.groups});
  final String id;
  final List<String> words;
  final List<ConnectGroup> groups;

  factory ConnectPuzzle.fromJson(Map<String, dynamic> j) => ConnectPuzzle(
        id: j['id'] as String? ?? 'daily',
        words: (j['words'] as List).cast<String>(),
        groups: [for (final g in j['groups'] as List) ConnectGroup.fromJson(g as Map<String, dynamic>)],
      );

  Map<String, dynamic> toJson() => {'id': id, 'words': words, 'groups': [for (final g in groups) g.toJson()]};
}

enum GuessOutcome { correct, oneAway, wrong, duplicate }

/// Rules engine mirroring docs/CONTRACT.md §3 CONNECT.
class ConnectGame {
  ConnectGame(this.puzzle) : remaining = List.of(puzzle.words);

  static const maxMistakes = 4;

  final ConnectPuzzle puzzle;
  final List<String> remaining;
  final List<ConnectGroup> solved = [];
  final Set<String> selected = {};
  final List<List<String>> guesses = [];
  final Set<String> _wrongKeys = {};
  int mistakes = 0;

  bool get isWon => solved.length == puzzle.groups.length;
  bool get isLost => mistakes >= maxMistakes;
  bool get isOver => isWon || isLost;

  void toggle(String w) {
    if (isOver) return;
    if (!selected.remove(w) && selected.length < 4) selected.add(w);
  }

  void deselectAll() => selected.clear();

  String _key(Iterable<String> ws) => (ws.toList()..sort()).join('|');

  GuessOutcome submit() {
    assert(selected.length == 4);
    final guess = selected.toList();
    final key = _key(guess);
    if (_wrongKeys.contains(key)) return GuessOutcome.duplicate;
    guesses.add(guess);
    for (final g in puzzle.groups) {
      if (solved.contains(g)) continue;
      if (_key(g.words) == key) {
        solved.add(g);
        remaining.removeWhere(guess.contains);
        selected.clear();
        return GuessOutcome.correct;
      }
    }
    _wrongKeys.add(key);
    mistakes++;
    final oneAway = puzzle.groups.any((g) => !solved.contains(g) && g.words.where(guess.contains).length == 3);
    if (isLost) {
      // Reveal the rest in difficulty order.
      for (final g in [...puzzle.groups]..sort((a, b) => a.level.compareTo(b.level))) {
        if (!solved.contains(g)) solved.add(g);
      }
      remaining.clear();
      selected.clear();
    }
    return oneAway ? GuessOutcome.oneAway : GuessOutcome.wrong;
  }

  /// Hint: reveals the easiest unsolved group's title and one of its words.
  (ConnectGroup, String)? hint() {
    final open = puzzle.groups.where((g) => !solved.contains(g)).toList()..sort((a, b) => a.level.compareTo(b.level));
    if (open.isEmpty) return null;
    final g = open.first;
    return (g, g.words.first);
  }

  void shuffle() => remaining.shuffle();
}
