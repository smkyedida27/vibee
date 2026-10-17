import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../services/content_repo.dart';
import '../common/game_flow.dart';
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
    Color(0xFFC9B8EC), // lavender
    Color(0xFFFFD3A6), // apricot
    Color(0xFFB5D1FF), // periwinkle
    Color(0xFFC4E5B4), // sage
    Color(0xFFE4E2DC), // stone
    Color(0xFFFFB4A3), // coral
    Color(0xFFEDF3A6), // citron
    Color(0xFFD3CBB8), // sand
    Color(0xFFEBB8D2), // rose
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
    if (finished) return;
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
      roundOver: finished,
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
                opacity: i < placed ? 1 : 0.22,
                child: const SizedBox.square(dimension: 20, child: CustomPaint(painter: _CrownPainter())),
              ),
            ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.ink, width: 2),
              ),
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
                      borderRadius: BorderRadius.circular(4),
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
    // The outer edge is drawn by the board frame.
    return (
      r > 0 && g[r - 1][c] != reg,
      c < n - 1 && g[r][c + 1] != reg,
      r < n - 1 && g[r + 1][c] != reg,
      c > 0 && g[r][c - 1] != reg,
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
    const thick = BorderSide(color: AppColors.ink, width: 1.6);
    final thin = BorderSide(color: AppColors.ink.withValues(alpha: 0.16), width: 0.5);
    return Semantics(
      button: true,
      label: '$label, ${mark.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: conflict ? Color.lerp(color, AppColors.danger, 0.4) : color,
            border: Border(
              top: borders.$1 ? thick : thin,
              right: borders.$2 ? thick : thin,
              bottom: borders.$3 ? thick : thin,
              left: borders.$4 ? thick : thin,
            ),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: switch (mark) {
                QueenMark.empty => const SizedBox.shrink(key: ValueKey('e')),
                QueenMark.cross => Icon(
                  Icons.close_rounded,
                  key: const ValueKey('x'),
                  color: AppColors.inkFaint,
                  size: 16,
                ),
                QueenMark.crown => FractionallySizedBox(
                  key: const ValueKey('q'),
                  widthFactor: 0.6,
                  heightFactor: 0.6,
                  child: CustomPaint(painter: _CrownPainter(conflict ? AppColors.danger : AppColors.ink)),
                ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat crown glyph (three points on a band).
class _CrownPainter extends CustomPainter {
  const _CrownPainter([this.color = AppColors.ink]);
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final paint = Paint()..color = color;
    final body = Path()
      ..moveTo(w * 0.08, h * 0.28)
      ..lineTo(w * 0.3, h * 0.52)
      ..lineTo(w * 0.5, h * 0.18)
      ..lineTo(w * 0.7, h * 0.52)
      ..lineTo(w * 0.92, h * 0.28)
      ..lineTo(w * 0.84, h * 0.74)
      ..lineTo(w * 0.16, h * 0.74)
      ..close();
    canvas.drawPath(body, paint);
    canvas.drawRRect(RRect.fromLTRBR(w * 0.16, h * 0.8, w * 0.84, h * 0.9, Radius.circular(h * 0.04)), paint);
    for (final x in [0.08, 0.5, 0.92]) {
      canvas.drawCircle(Offset(w * x, h * (x == 0.5 ? 0.14 : 0.24)), w * 0.065, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CrownPainter old) => old.color != color;
}

/// Exposed for tests/screenshots.
TextStyle queensLabelStyle() => AppText.body(12);
