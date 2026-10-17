import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
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

const _primary = Candy(Color(0xFFF0E8F5), AppColors.primary, Color(0xFF4329C9));

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
                const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.inkFaint),
                const SizedBox(height: 12),
                Text('Something went wrong', textAlign: TextAlign.center, style: AppText.display(22)),
                const SizedBox(height: 8),
                Text(
                  snap.error is StateError
                      ? (snap.error! as StateError).message
                      : 'We couldn\'t load this puzzle. Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppText.body(15, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 20),
                CandyButton(
                  label: 'Try again',
                  candy: _primary,
                  width: 220,
                  onTap: () => setState(() => _load = _run()),
                ),
                const SizedBox(height: 12),
                CandyButton(label: 'Back', candy: Candy.white, width: 220, depth: 0, onTap: () => context.pop()),
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
    backgroundColor: AppColors.bg,
    body: SafeArea(
      child: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}

class _Loader extends StatelessWidget {
  const _Loader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primary,
            backgroundColor: AppColors.divider,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Preparing your puzzle…',
          style: AppText.body(15, color: AppColors.inkSoft, weight: FontWeight.w600),
        ),
      ],
    );
  }
}
