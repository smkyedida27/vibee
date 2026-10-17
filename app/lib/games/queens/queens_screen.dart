import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/game_art.dart';
import '../../services/content_repo.dart';
import '../common/game_flow.dart';
import '../common/results_overlay.dart';
import 'queens_logic.dart';

class QueensScreen extends StatefulWidget {
  const QueensScreen({super.key, required this.request, required this.puzzle});
  final PlayRequest request;
  final QueensPuzzle puzzle;

  @override
  State<QueensScreen> createState() => _QueensScreenState();
}

class _QueensScreenState extends State<QueensScreen> with GameFlow {
  late final QueensBoard board = QueensBoard(widget.puzzle);
  (int, int)? _lastPlaced;
  QueenMark? _dragMode;
  final Set<(int, int)> _dragged = {};

  @override
  PlayRequest get request => widget.request;

  static const regionColors = [
    Color(0xFFFFB3C7), // pink
    Color(0xFFFFE08A), // lemon
    Color(0xFFA8E6FF), // sky
    Color(0xFFC9B6FF), // lilac
    Color(0xFFA9F0C0), // mint
    Color(0xFFFFC69E), // peach
    Color(0xFFB6F2EE), // aqua
    Color(0xFFE7E3EF), // cloud
    Color(0xFFF7B2F0), // bubblegum
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startFlow());
  }

  void _tap(int r, int c) {
    if (finished) return;
    setState(() {
      board.cycle(r, c);
      if (board.marks[r][c] == QueenMark.crown) {
        _lastPlaced = (r, c);
        Audio.instance.fx(board.conflicts().contains((r, c)) ? Sfx.wrong : Sfx.pop, HapticKind.medium);
      } else {
        Audio.instance.fx(Sfx.tap, HapticKind.select);
      }
    });
    _checkWin();
  }

  void _checkWin() {
    if (!board.solved) return;
    final stars = hintsUsed == 0 ? 3 : (hintsUsed == 1 ? 2 : 1);
    finish(
      RoundResult(
        won: true,
        stars: stars,
        submission: {'queens': board.submission},
        detail: '${board.size}×${board.size} board cleared',
      ),
    );
  }

  // Drag across empty cells to paint ✕ marks (or erase them), like a highlighter.
  void _dragAt(Offset local, double cell) {
    final r = (local.dy / cell).floor(), c = (local.dx / cell).floor();
    if (r < 0 || c < 0 || r >= board.size || c >= board.size) return;
    if (!_dragged.add((r, c))) return;
    final current = board.marks[r][c];
    _dragMode ??= current == QueenMark.cross ? QueenMark.empty : QueenMark.cross;
    if (current == QueenMark.crown) return;
    setState(() => board.set(r, c, _dragMode!));
    Audio.instance.haptic(HapticKind.select);
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = board.conflicts();
    final placed = board.crowns.length;
    return GameScaffold(
      request: request,
      elapsed: elapsed,
      confetti: confetti,
      onHint: () async {
        if (await requestHint()) {
          setState(() => _lastPlaced = board.hint());
          _checkWin();
        }
      },
      status: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < board.size; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: i < placed ? 1 : 0.28,
                child: const GameArt(ArtKind.crown, size: 24),
              ),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: BoardFrame(
              candy: Candy.gold,
              child: LayoutBuilder(
                builder: (context, box) {
                  final cell = box.maxWidth / board.size;
                  return GestureDetector(
                    onPanStart: (d) {
                      _dragMode = null;
                      _dragged.clear();
                      _dragAt(d.localPosition, cell);
                    },
                    onPanUpdate: (d) => _dragAt(d.localPosition, cell),
                    onPanEnd: (_) => _dragged.clear(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          for (var r = 0; r < board.size; r++)
                            for (var c = 0; c < board.size; c++)
                              Positioned(
                                left: c * cell,
                                top: r * cell,
                                width: cell,
                                height: cell,
                                child: _Cell(
                                  color: regionColors[widget.puzzle.regions[r][c] % regionColors.length],
                                  mark: board.marks[r][c],
                                  conflict: conflicts.contains((r, c)),
                                  pop: _lastPlaced == (r, c),
                                  borders: _borders(r, c),
                                  onTap: () => _tap(r, c),
                                  label: 'Row ${r + 1}, column ${c + 1}',
                                ),
                              ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      toolbar: Row(
        children: [
          ToolButton(icon: Icons.undo_rounded, label: 'Undo', onTap: board.canUndo ? () => setState(board.undo) : null),
          ToolButton(icon: Icons.auto_fix_high_rounded, label: 'Auto ✕', onTap: () => setState(board.autoCross)),
          ToolButton(icon: Icons.restart_alt_rounded, label: 'Clear', onTap: () => setState(board.reset)),
        ],
      ),
    );
  }

  /// Thick borders where neighbouring cells belong to different regions.
  (bool, bool, bool, bool) _borders(int r, int c) {
    final g = widget.puzzle.regions;
    final reg = g[r][c];
    final n = board.size;
    return (
      r == 0 || g[r - 1][c] != reg,
      c == n - 1 || g[r][c + 1] != reg,
      r == n - 1 || g[r + 1][c] != reg,
      c == 0 || g[r][c - 1] != reg,
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.color,
    required this.mark,
    required this.conflict,
    required this.pop,
    required this.borders,
    required this.onTap,
    required this.label,
  });

  final Color color;
  final QueenMark mark;
  final bool conflict;
  final bool pop;
  final (bool, bool, bool, bool) borders;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    const thick = BorderSide(color: AppColors.ink, width: 2.2);
    final thin = BorderSide(color: AppColors.ink.withValues(alpha: 0.12), width: 0.6);
    return Semantics(
      button: true,
      label: '$label, ${mark.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: conflict ? Color.lerp(color, AppColors.danger, 0.45) : color,
            border: Border(
              top: borders.$1 ? thick : thin,
              right: borders.$2 ? thick : thin,
              bottom: borders.$3 ? thick : thin,
              left: borders.$4 ? thick : thin,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.elasticOut,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: switch (mark) {
                QueenMark.empty => const SizedBox.shrink(key: ValueKey('e')),
                QueenMark.cross => Icon(
                  Icons.close_rounded,
                  key: const ValueKey('x'),
                  color: AppColors.ink.withValues(alpha: 0.45),
                  size: 18,
                ),
                QueenMark.crown => const FractionallySizedBox(
                  key: ValueKey('q'),
                  widthFactor: 0.72,
                  heightFactor: 0.72,
                  child: FittedBox(child: GameArt(ArtKind.crown, size: 40)),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Exposed for tests/screenshots.
TextStyle queensLabelStyle() => AppText.body(12);
