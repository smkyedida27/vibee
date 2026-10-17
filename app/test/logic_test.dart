import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/util/rng.dart';
import 'package:puzzle_hub/games/connect/connect_logic.dart';
import 'package:puzzle_hub/games/ladder/ladder_logic.dart';
import 'package:puzzle_hub/games/merge/merge_logic.dart';
import 'package:puzzle_hub/games/queens/queens_logic.dart';
import 'package:puzzle_hub/games/sudoku/sudoku_logic.dart';

void main() {
  group('mulberry32 matches contract vectors', () {
    const vectors = {
      0: [1144304738, 1416247, 958946056, 627933444, 2007157716],
      1: [2693262067, 11749833, 2265367787, 4213581821, 4159151403],
      42: [2581720956, 1925393290, 3661312704, 2876485805, 750819978],
      20261011: [1488163886, 3496767163, 2460547021, 1222184908, 208299103],
    };
    vectors.forEach((seed, expected) {
      test('seed $seed', () {
        final r = Rng(seed);
        expect([for (var i = 0; i < 5; i++) r.next()], expected);
      });
    });
  });

  group('Crowns', () {
    for (final size in [5, 6, 7, 8, 9]) {
      test('generates a unique $size×$size puzzle', () {
        final sw = Stopwatch()..start();
        final p = QueensLogic.generate(size, 1000 + size);
        expect(QueensLogic.countSolutions(p.regions, size), 1);
        expect(QueensLogic.isValidSolution(p, p.solution), isTrue);
        // Every region present and contiguous count == size.
        expect(p.regions.expand((r) => r).toSet().length, size);
        // ignore: avoid_print
        print('crowns $size: ${sw.elapsedMilliseconds}ms');
      });
    }
    test('is deterministic', () {
      expect(QueensLogic.generate(7, 9).toJson(), QueensLogic.generate(7, 9).toJson());
    });
    test('rejects touching crowns', () {
      final p = QueensLogic.generate(6, 3);
      final bad = List.of(p.solution);
      bad[1] = bad[0] + 1;
      expect(QueensLogic.isValidSolution(p, bad), isFalse);
    });
  });

  group('Sudoku', () {
    for (final givens in [40, 32, 28, 25]) {
      test('generates unique puzzle with ~$givens givens', () {
        final sw = Stopwatch()..start();
        final p = SudokuLogic.generate(givens, givens * 7);
        expect(SudokuLogic.countSolutions(p.givens), 1);
        expect(SudokuLogic.isValidSolution(p.givens, p.solution), isTrue);
        final n = p.givens.where((v) => v != 0).length;
        expect(n, lessThanOrEqualTo(givens + 6));
        // ignore: avoid_print
        print('sudoku $givens: actual $n in ${sw.elapsedMilliseconds}ms');
      });
    }
    test('board tracks mistakes and solves', () {
      final b = SudokuBoard(SudokuLogic.generate(40, 1));
      final empty = b.values.indexOf(0);
      final wrong = b.puzzle.solution[empty] % 9 + 1;
      expect(b.enter(empty, wrong), isFalse);
      expect(b.mistakes, 1);
      expect(b.enter(empty, wrong), isFalse, reason: 'same wrong digit again');
      expect(b.mistakes, 1, reason: 'repeating an entry must not cost another life');
      while (b.hint() != null) {}
      expect(b.solved, isTrue);
    });
  });

  group('Word Ladder', () {
    final dict = LadderDictionary(File('assets/content/words4.txt').readAsLinesSync());
    test('hint routes avoid words already used', () {
      final p = dict.generate(4, 7);
      final direct = dict.shortestPath(p.start, p.target)!;
      final avoid = {direct[1]};
      final detour = dict.shortestPath(p.start, p.target, avoid: avoid);
      if (detour != null) expect(detour.contains(direct[1]), isFalse);
    });
    for (final par in [3, 4, 5, 6]) {
      test('par $par puzzles have a shortest path of par steps', () {
        final p = dict.generate(par, par * 31);
        final path = dict.shortestPath(p.start, p.target)!;
        expect(path.length - 1, par);
        expect(dict.isValidPath(p, path), isTrue);
      });
    }
    test('rejects non-words and jumps', () {
      final p = LadderPuzzle(start: 'COLD', target: 'WARM', par: 4);
      expect(dict.isValidPath(p, ['COLD', 'CORD', 'CARD', 'WARD', 'WARM']), isTrue);
      expect(dict.isValidPath(p, ['COLD', 'WARM']), isFalse);
      expect(dict.isValidPath(p, ['COLD', 'XOLD', 'WARM']), isFalse);
    });
  });

  group('Number Merge', () {
    test('slides and merges once per move toward the wall', () {
      final g = MergeGame(MergePuzzle(seed: 1, target: 2048));
      g.tiles
        ..clear()
        ..addAll([Tile(100, 2, 0, 0), Tile(101, 2, 0, 1), Tile(102, 2, 0, 2), Tile(103, 2, 0, 3)]);
      g.move(MoveDir.left);
      expect(g.grid.sublist(0, 2), [4, 4]);
      expect(g.tiles.length, 3); // two merged tiles + one spawn
      expect(g.score, 8);
    });
    test('replay is deterministic', () {
      const moves = 'LURDLLURDDRULDLURDLURDLLLUUURRRDDDLURD';
      final a = MergeGame.replay(MergePuzzle(seed: 777, target: 256), moves);
      final b = MergeGame.replay(MergePuzzle(seed: 777, target: 256), moves);
      expect(a.grid, b.grid);
      expect(a.score, b.score);
    });
    test('no-op moves do not spawn', () {
      final g = MergeGame(MergePuzzle(seed: 5, target: 64));
      g.tiles
        ..clear()
        ..add(Tile(1, 2, 0, 0));
      expect(g.move(MoveDir.left), isFalse);
      expect(g.tiles.length, 1);
      expect(g.moves.toString(), '');
    });
  });

  group('Word Connect', () {
    final data = jsonDecode(File('assets/content/connect.json').readAsStringSync()) as Map<String, dynamic>;
    final puzzles = [for (final p in data['puzzles'] as List) ConnectPuzzle.fromJson(p as Map<String, dynamic>)];
    test('content is well formed', () {
      expect(puzzles.length, greaterThanOrEqualTo(30));
      for (final p in puzzles) {
        expect(p.words.toSet().length, 16, reason: p.id);
        expect(p.groups.expand((g) => g.words).toSet(), p.words.toSet(), reason: p.id);
      }
    });
    test('hints reveal a new word each time and the share grid hides answers', () {
      final g = ConnectGame(puzzles.first);
      final seen = <String>{};
      for (var i = 0; i < 6; i++) {
        final h = g.hint(reveal: true)!;
        expect(seen.add(h.$2), isTrue);
      }
      for (final w in puzzles.first.groups[0].words) {
        g.toggle(w);
      }
      g.submit();
      expect(g.shareGrid.split('\n'), hasLength(1));
      expect(g.shareGrid.runes.length, 4);
      for (final w in puzzles.first.words) {
        expect(g.shareGrid.contains(w), isFalse);
      }
    });
    test('solves and detects one-away', () {
      final g = ConnectGame(puzzles.first);
      final a = puzzles.first.groups[0].words, b = puzzles.first.groups[1].words;
      for (final w in [...a.take(3), b.first]) {
        g.toggle(w);
      }
      expect(g.submit(), GuessOutcome.oneAway);
      expect(g.mistakes, 1);
      g.deselectAll();
      for (final grp in puzzles.first.groups) {
        grp.words.forEach(g.toggle);
        expect(g.submit(), GuessOutcome.correct);
      }
      expect(g.isWon, isTrue);
    });
    test('four mistakes loses', () {
      final g = ConnectGame(puzzles[1]);
      final gs = puzzles[1].groups;
      for (var i = 0; i < 4; i++) {
        g.deselectAll();
        for (final w in [gs[0].words[0], gs[1].words[0], gs[2].words[0], gs[3].words[i]]) {
          g.toggle(w);
        }
        g.submit();
      }
      expect(g.isLost, isTrue);
    });
  });
}
