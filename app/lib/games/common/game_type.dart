import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';

enum GameType { connect, queens, sudoku, ladder, merge }

enum Difficulty { easy, medium, hard, expert }

extension GameTypeX on GameType {
  /// Wire name used by the API (docs/CONTRACT.md §3).
  String get wire => name.toUpperCase();

  static GameType fromWire(String s) => GameType.values.firstWhere((g) => g.wire == s.toUpperCase());

  String get title => switch (this) {
        GameType.connect => 'Word Connect',
        GameType.queens => 'Crowns',
        GameType.sudoku => 'Sudoku',
        GameType.ladder => 'Word Ladder',
        GameType.merge => 'Number Merge',
      };

  String get tagline => switch (this) {
        GameType.connect => 'Find the four hidden groups',
        GameType.queens => 'One crown per row, column & colour',
        GameType.sudoku => 'Classic 9×9 number logic',
        GameType.ladder => 'Change one letter at a time',
        GameType.merge => 'Slide, merge, reach the goal',
      };

  Candy get candy => switch (this) {
        GameType.connect => Candy.pink,
        GameType.queens => Candy.gold,
        GameType.sudoku => Candy.blue,
        GameType.ladder => Candy.purple,
        GameType.merge => Candy.green,
      };

  IconData get icon => switch (this) {
        GameType.connect => Icons.grid_view_rounded,
        GameType.queens => Icons.workspace_premium_rounded,
        GameType.sudoku => Icons.apps_rounded,
        GameType.ladder => Icons.swap_vert_rounded,
        GameType.merge => Icons.view_module_rounded,
      };

  String get howTo => switch (this) {
        GameType.connect =>
          'Sixteen words hide four groups of four. Select four words that share a theme and tap Submit. '
              'Four mistakes and the puzzle ends — so think before you guess!',
        GameType.queens =>
          'Place exactly one crown in every row, every column and every colour region. '
              'Crowns can never touch each other — not even diagonally. Tap once to mark ✕, twice for a crown.',
        GameType.sudoku =>
          'Fill the grid so every row, column and 3×3 box contains the digits 1–9 exactly once. '
              'Use notes for candidates. Three mistakes and it\'s over.',
        GameType.ladder =>
          'Turn the start word into the target word. Each step changes exactly one letter and must make a real word. '
              'Match par for three stars.',
        GameType.merge =>
          'Swipe to slide every tile. Two equal tiles merge into one. Reach the target tile before the board fills up.',
      };
}

extension DifficultyX on Difficulty {
  String get wire => name.toUpperCase();
  static Difficulty fromWire(String s) => Difficulty.values.firstWhere((d) => d.wire == s.toUpperCase());
  String get label => switch (this) {
        Difficulty.easy => 'Easy',
        Difficulty.medium => 'Medium',
        Difficulty.hard => 'Hard',
        Difficulty.expert => 'Expert',
      };
  Candy get candy => switch (this) {
        Difficulty.easy => Candy.green,
        Difficulty.medium => Candy.blue,
        Difficulty.hard => Candy.orange,
        Difficulty.expert => Candy.red,
      };
}
