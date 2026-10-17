import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/celebrations.dart';
import '../../core/ui/pressable.dart';
import '../../core/ui/game_art.dart';
import '../../services/content_repo.dart';
import '../common/game_flow.dart';
import 'sudoku_logic.dart';

class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key, required this.request, required this.puzzle});
  final PlayRequest request;
  final SudokuPuzzle puzzle;

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> with GameFlow {
  late final SudokuBoard board = SudokuBoard(widget.puzzle);
  static const maxMistakes = 3;
  int? _sel;
  bool _notes = false;
  int _streak = 0; // consecutive completed units without a mistake
  int? _hintFlash;

  @override
  PlayRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    _sel = board.values.indexOf(0);
    WidgetsBinding.instance.addPostFrameCallback((_) => startFlow());
  }

  int get _mistakesLeft => maxMistakes - board.mistakes;

  void _input(int d) {
    final i = _sel;
    if (i == null || finished || board.isGiven(i)) return;
    if (_notes) {
      setState(() => board.toggleNote(i, d));
      Audio.instance.fx(Sfx.tap, HapticKind.select);
      return;
    }
    final ok = board.enter(i, d);
    setState(() {});
    if (ok) {
      final unit = _unitComplete(i);
      Audio.instance.fx(unit ? Sfx.success : Sfx.pop, HapticKind.light);
      if (unit && !board.solved) {
        _streak++;
        PraiseOverlay.show(
          context,
          _streak >= 3 ? 'On fire!' : (_streak == 2 ? 'Great!' : 'Nice!'),
          color: Candy.blue.base,
        );
      }
    } else {
      _streak = 0;
      Audio.instance.fx(Sfx.wrong, HapticKind.heavy);
    }
    _checkSolved(i);
  }

  void _checkSolved(int i) {
    if (board.solved) {
      final stars = board.mistakes == 0 && hintsUsed == 0 ? 3 : (board.mistakes <= 1 && hintsUsed <= 1 ? 2 : 1);
      finish(
        RoundResult(
          won: true,
          stars: stars,
          mistakes: board.mistakes,
          submission: {'grid': board.values.join(), 'mistakes': board.mistakes},
          detail: board.mistakes == 0
              ? 'Flawless — no mistakes!'
              : '${board.mistakes} mistake${board.mistakes == 1 ? '' : 's'}',
        ),
      );
    } else if (board.mistakes >= maxMistakes) {
      finish(
        RoundResult(won: false, stars: 0, submission: const {}, mistakes: board.mistakes),
        onContinue: () => setState(() {
          board.mistakes = maxMistakes - 1;
          board.erase(i);
        }),
      );
    }
  }

  bool _unitComplete(int i) {
    bool full(Iterable<int> cells) => cells.every((k) => board.values[k] == widget.puzzle.solution[k]);
    final r = i ~/ 9, c = i % 9, b = SudokuLogic.box(i);
    return full([for (var k = 0; k < 9; k++) r * 9 + k]) ||
        full([for (var k = 0; k < 9; k++) k * 9 + c]) ||
        full([
          for (var k = 0; k < 81; k++)
            if (SudokuLogic.box(k) == b) k,
        ]);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      request: request,
      elapsed: elapsed,
      roundOver: finished,
      confetti: confetti,
      onHint: () async {
        if (await requestHint()) {
          setState(() {
            _hintFlash = board.hint();
            _sel = _hintFlash;
          });
          if (_sel != null) _checkSolved(_sel!);
        }
      },
      status: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Mistakes', style: AppText.body(14, color: AppColors.inkSoft)),
          const SizedBox(width: 8),
          for (var i = 0; i < maxMistakes; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedScale(
                scale: i < _mistakesLeft ? 1 : 0.7,
                duration: const Duration(milliseconds: 300),
                child: Opacity(opacity: i < _mistakesLeft ? 1 : 0.2, child: const GameArt(ArtKind.heart, size: 20)),
              ),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final cell = box.maxWidth / 9;
                    return Stack(
                      children: [
                        for (var i = 0; i < 81; i++)
                          Positioned(
                            left: (i % 9) * cell,
                            top: (i ~/ 9) * cell,
                            width: cell,
                            height: cell,
                            child: _cell(i, cell),
                          ),
                        IgnorePointer(
                          child: CustomPaint(size: box.biggest, painter: _GridPainter()),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      toolbar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ToolButton(
                icon: Icons.undo_rounded,
                label: 'Undo',
                onTap: board.canUndo ? () => setState(board.undo) : null,
              ),
              ToolButton(
                icon: Icons.backspace_rounded,
                label: 'Erase',
                onTap: _sel == null ? null : () => setState(() => board.erase(_sel!)),
              ),
              ToolButton(
                icon: Icons.edit_note_rounded,
                label: _notes ? 'Notes ON' : 'Notes',
                active: _notes,
                onTap: () => setState(() => _notes = !_notes),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var d = 1; d <= 9; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _DigitKey(digit: d, remaining: board.remainingOf(d), notes: _notes, onTap: () => _input(d)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(int i, double size) {
    final v = board.values[i];
    final sel = _sel;
    final given = board.isGiven(i);
    final wrong = v != 0 && v != widget.puzzle.solution[i];
    Color bg = AppColors.surface;
    if (sel != null) {
      final sameUnit = i ~/ 9 == sel ~/ 9 || i % 9 == sel % 9 || SudokuLogic.box(i) == SudokuLogic.box(sel);
      if (sameUnit) bg = const Color(0xFFF4F2EC);
      if (v != 0 && v == board.values[sel]) bg = const Color(0xFFE4DEFD);
      if (i == sel) bg = const Color(0xFFCFC4FC);
    }
    if (wrong) bg = Candy.red.light;
    if (i == _hintFlash) bg = Candy.gold.light;
    return Semantics(
      button: true,
      label: 'Row ${i ~/ 9 + 1} column ${i % 9 + 1}, ${v == 0 ? 'empty' : v}',
      child: GestureDetector(
        onTap: () {
          Audio.instance.haptic(HapticKind.select);
          setState(() {
            _sel = i;
            _hintFlash = null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          color: bg,
          alignment: Alignment.center,
          child: v != 0
              ? TweenAnimationBuilder<double>(
                  key: ValueKey('$i-$v'),
                  tween: Tween(begin: given ? 1 : 0.7, end: 1),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Text(
                    '$v',
                    style: given
                        ? AppText.display(size * 0.56, color: AppColors.ink)
                        : AppText.body(
                            size * 0.56,
                            color: wrong ? AppColors.danger : AppColors.primary,
                            weight: FontWeight.w600,
                          ),
                  ),
                )
              : board.notes[i].isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: GridView.count(
                    crossAxisCount: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                      for (var d = 1; d <= 9; d++)
                        Center(
                          child: Text(
                            board.notes[i].contains(d) ? '$d' : '',
                            style: AppText.body(size * 0.2, color: AppColors.inkSoft, weight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _DigitKey extends StatelessWidget {
  const _DigitKey({required this.digit, required this.remaining, required this.notes, required this.onTap});
  final int digit;
  final int remaining;
  final bool notes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = remaining <= 0;
    final fg = done ? AppColors.inkFaint : (notes ? AppColors.inkSoft : AppColors.ink);
    return Pressable(
      onTap: done ? null : onTap,
      scale: 0.94,
      sound: Sfx.tap,
      semanticLabel: '$digit, $remaining left',
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: done ? AppColors.bg : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$digit',
              style: notes
                  ? AppText.body(22, color: fg, weight: FontWeight.w600)
                  : AppText.display(24, color: fg, height: 1.05),
            ),
            Text(
              '$remaining',
              style: AppText.body(9, color: AppColors.inkFaint, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 9;
    final thin = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final thick = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 2;
    for (var k = 1; k < 9; k++) {
      final p = k % 3 == 0 ? thick : thin;
      canvas.drawLine(Offset(k * cell, 0), Offset(k * cell, size.height), p);
      canvas.drawLine(Offset(0, k * cell), Offset(size.width, k * cell), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
