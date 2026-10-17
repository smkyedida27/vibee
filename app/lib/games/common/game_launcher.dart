import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/outlined_text.dart';
import '../../services/content_repo.dart';
import '../../services/services.dart';
import '../connect/connect_logic.dart';
import '../connect/connect_screen.dart';
import '../ladder/ladder_logic.dart';
import '../ladder/ladder_screen.dart';
import '../merge/merge_logic.dart';
import '../merge/merge_screen.dart';
import '../queens/queens_logic.dart';
import '../queens/queens_screen.dart';
import '../sudoku/sudoku_logic.dart';
import '../sudoku/sudoku_screen.dart';
import 'game_type.dart';

/// Resolves a [PlayRequest] (possibly fetching the daily set), generates the puzzle
/// off the UI thread, then hands over to the matching game screen.
class GameLauncher extends StatefulWidget {
  const GameLauncher({super.key, required this.resolve});
  final Future<PlayRequest> Function(AppServices s) resolve;

  @override
  State<GameLauncher> createState() => _GameLauncherState();
}

class _GameLauncherState extends State<GameLauncher> {
  late Future<(PlayRequest, Object)> _load;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load = _run();
  }

  Future<(PlayRequest, Object)> _run() async {
    final s = context.services;
    final req = await widget.resolve(s);
    final puzzle = await s.content.build(req);
    // Small minimum so the loading card doesn't flash.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return (req, puzzle);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(PlayRequest, Object)>(
      future: _load,
      builder: (context, snap) {
        if (snap.hasError) {
          return _LoadingScaffold(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const OutlinedText('Oops!', size: 40),
                const SizedBox(height: 8),
                Text(
                  snap.error is StateError
                      ? (snap.error! as StateError).message
                      : 'We couldn\'t load this puzzle. Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppText.body(16, color: Colors.white),
                ),
                const SizedBox(height: 20),
                CandyButton(
                  label: 'Try again',
                  candy: Candy.orange,
                  width: 220,
                  onTap: () => setState(() => _load = _run()),
                ),
                const SizedBox(height: 12),
                CandyButton(label: 'Back', candy: Candy.grey, width: 220, onTap: () => context.pop()),
              ],
            ),
          );
        }
        if (!snap.hasData) return const _LoadingScaffold(child: _Loader());
        final (req, p) = snap.data!;
        return switch (req.game) {
          GameType.connect => ConnectScreen(request: req, puzzle: p as ConnectPuzzle),
          GameType.queens => QueensScreen(request: req, puzzle: p as QueensPuzzle),
          GameType.sudoku => SudokuScreen(request: req, puzzle: p as SudokuPuzzle),
          GameType.ladder => LadderScreen(request: req, puzzle: p as LadderPuzzle),
          GameType.merge => MergeScreen(request: req, puzzle: p as MergePuzzle),
        };
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CandyBackground(
      child: SafeArea(
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      ),
    ),
  );
}

class _Loader extends StatefulWidget {
  const _Loader();
  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const candies = [Candy.pink, Candy.gold, Candy.blue, Candy.green];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 4; i++)
                Transform.translate(
                  offset: Offset(0, -18 * math.sin(((_c.value + i * 0.18) % 1.0) * math.pi)),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: candies[i].face,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: candies[i].dark, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const OutlinedText('Baking your puzzle…', size: 22),
      ],
    );
  }
}
