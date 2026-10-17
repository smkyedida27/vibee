import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/celebrations.dart';
import '../../core/ui/dialogs.dart';
import '../../services/content_repo.dart';
import '../common/game_flow.dart';
import 'merge_logic.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key, required this.request, required this.puzzle});
  final PlayRequest request;
  final MergePuzzle puzzle;

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> with GameFlow {
  late final MergeGame game = MergeGame(widget.puzzle);
  final _focus = FocusNode();
  Offset _dragDelta = Offset.zero;
  MoveDir? _suggestion;
  int _lastScoreGain = 0;
  int _gainKey = 0;

  @override
  PlayRequest get request => widget.request;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startFlow();
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _move(MoveDir d) {
    if (finished) return;
    final before = game.score;
    if (!game.move(d)) {
      Audio.instance.haptic(HapticKind.light);
      return;
    }
    final gained = game.score - before;
    setState(() {
      _suggestion = null;
      _lastScoreGain = gained;
      if (gained > 0) _gainKey++;
    });
    if (gained > 0) {
      Audio.instance.fx(Sfx.merge, gained >= 128 ? HapticKind.heavy : HapticKind.medium);
      if (gained >= 64 && !game.won) {
        PraiseOverlay.show(
          context,
          gained >= 256 ? 'Massive!' : (gained >= 128 ? 'Huge merge!' : 'Combo!'),
          color: Candy.green.base,
        );
      }
    } else {
      Audio.instance.play(Sfx.whoosh, volume: 0.25);
    }
    if (game.won) {
      _end(true);
    } else if (!game.canMove) {
      _end(false);
    }
  }

  void _end(bool reachedTarget) {
    final t = widget.puzzle.target;
    final max = game.maxTile;
    final stars = max >= t ? 3 : (max >= t ~/ 2 ? 2 : (max >= t ~/ 4 ? 1 : 0));
    final submission = {'moves': game.moves.toString()};
    if (request.source == PlaySource.daily) {
      // The daily Merge is one scored run: every finished run is submitted and ranked by score
      // (docs/CONTRACT.md), whether or not it reached the target.
      finish(
        RoundResult(
          won: true,
          stars: stars.clamp(1, 3),
          submission: submission,
          detail: reachedTarget
              ? 'Best tile $max • Score ${game.score}'
              : 'Out of moves • Best tile $max • Score ${game.score}',
        ),
      );
    } else if (stars > 0) {
      finish(
        RoundResult(won: true, stars: stars, submission: submission, detail: 'Best tile $max • Score ${game.score}'),
      );
    } else {
      finish(RoundResult(won: false, stars: 0, submission: submission), onContinue: _clearSmallest);
    }
  }

  void _clearSmallest() {
    final sorted = [...game.tiles]..sort((a, b) => a.value.compareTo(b.value));
    setState(() {
      for (final t in sorted.take(4)) {
        game.tiles.remove(t);
      }
    });
    toast(context, 'Cleared 4 tiles — keep merging!', icon: Icons.auto_awesome_rounded);
  }

  MoveDir? _bestMove() {
    MoveDir? best;
    var bestScore = -1;
    for (final d in MoveDir.values) {
      // Simulate on a copy using the same rules (grid only).
      final g = List<int>.of(game.grid);
      final (moved, gain) = _simulate(g, d, game.size);
      if (!moved) continue;
      final empties = g.where((v) => v == 0).length;
      final s = gain * 2 + empties * 10 + (d == MoveDir.down || d == MoveDir.left ? 5 : 0);
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
    return best;
  }

  static (bool, int) _simulate(List<int> g, MoveDir d, int n) {
    var moved = false, gain = 0;
    for (var line = 0; line < n; line++) {
      final idx = [
        for (var k = 0; k < n; k++)
          switch (d) {
            MoveDir.left => line * n + k,
            MoveDir.right => line * n + (n - 1 - k),
            MoveDir.up => k * n + line,
            MoveDir.down => (n - 1 - k) * n + line,
          },
      ];
      final vals = [
        for (final i in idx)
          if (g[i] != 0) g[i],
      ];
      final out = <int>[];
      for (var i = 0; i < vals.length; i++) {
        if (i + 1 < vals.length && vals[i] == vals[i + 1]) {
          out.add(vals[i] * 2);
          gain += vals[i] * 2;
          i++;
        } else {
          out.add(vals[i]);
        }
      }
      for (var k = 0; k < n; k++) {
        final v = k < out.length ? out[k] : 0;
        if (g[idx[k]] != v) moved = true;
        g[idx[k]] = v;
      }
    }
    return (moved, gain);
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.puzzle.target;
    final progress = (math.log(game.maxTile) / math.log(target)).clamp(0.0, 1.0);
    return KeyboardListener(
      focusNode: _focus,
      onKeyEvent: (e) {
        if (e is! KeyDownEvent) return;
        final d = switch (e.logicalKey) {
          LogicalKeyboardKey.arrowLeft => MoveDir.left,
          LogicalKeyboardKey.arrowRight => MoveDir.right,
          LogicalKeyboardKey.arrowUp => MoveDir.up,
          LogicalKeyboardKey.arrowDown => MoveDir.down,
          _ => null,
        };
        if (d != null) _move(d);
      },
      child: GameScaffold(
        request: request,
        elapsed: elapsed,
        roundOver: finished,
        clock: clock,
        confetti: confetti,
        onHint: () async {
          if (await requestHint()) setState(() => _suggestion = _bestMove());
        },
        status: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ScoreBox(label: 'SCORE', value: game.score, gain: _lastScoreGain, gainKey: _gainKey),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScoreBox(label: 'GOAL', value: target, candy: Candy.gold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Container(height: 8, color: AppColors.divider),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    widthFactor: progress,
                    child: Container(height: 8, color: Candy.green.base),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onPanStart: (_) => _dragDelta = Offset.zero,
                onPanUpdate: (d) => _dragDelta += d.delta,
                onPanEnd: (_) {
                  final v = _dragDelta;
                  if (v.distance < 24) return;
                  _move(
                    v.dx.abs() > v.dy.abs()
                        ? (v.dx > 0 ? MoveDir.right : MoveDir.left)
                        : (v.dy > 0 ? MoveDir.down : MoveDir.up),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final n = game.size;
                      const gap = 8.0;
                      final cell = (box.maxWidth - gap * (n + 1)) / n;
                      Offset pos(int r, int c) => Offset(gap + c * (cell + gap), gap + r * (cell + gap));
                      return Stack(
                        children: [
                          for (var r = 0; r < n; r++)
                            for (var c = 0; c < n; c++)
                              Positioned(
                                left: pos(r, c).dx,
                                top: pos(r, c).dy,
                                width: cell,
                                height: cell,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.divider,
                                    borderRadius: BorderRadius.circular(cell * 0.14),
                                  ),
                                ),
                              ),
                          for (final t in game.removed)
                            AnimatedPositioned(
                              key: ValueKey('gone-${t.id}'),
                              duration: const Duration(milliseconds: 110),
                              left: pos(t.row, t.col).dx,
                              top: pos(t.row, t.col).dy,
                              width: cell,
                              height: cell,
                              child: _TileView(value: t.value, size: cell),
                            ),
                          for (final t in game.tiles)
                            AnimatedPositioned(
                              key: ValueKey(t.id),
                              duration: const Duration(milliseconds: 110),
                              curve: Curves.easeOut,
                              left: pos(t.row, t.col).dx,
                              top: pos(t.row, t.col).dy,
                              width: cell,
                              height: cell,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey('${t.id}-${t.value}'),
                                tween: Tween(begin: t.spawnedThisMove ? 0.0 : (t.mergedThisMove ? 1.12 : 1.0), end: 1),
                                duration: Duration(milliseconds: t.spawnedThisMove ? 200 : 180),
                                curve: t.spawnedThisMove ? Curves.easeOutBack : Curves.easeOut,
                                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                                child: _TileView(value: t.value, size: cell),
                              ),
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
        toolbar: SizedBox(
          height: 56,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _suggestion == null
                  ? Text(
                      'Swipe to merge matching tiles',
                      key: const ValueKey('t'),
                      style: AppText.body(14, color: AppColors.inkSoft),
                    )
                  : Row(
                      key: ValueKey(_suggestion),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Try swiping',
                          style: AppText.body(15, color: AppColors.ink, weight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Transform.rotate(
                          angle: switch (_suggestion!) {
                            MoveDir.right => 0,
                            MoveDir.down => math.pi / 2,
                            MoveDir.left => math.pi,
                            MoveDir.up => -math.pi / 2,
                          },
                          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 30),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.label,
    required this.value,
    this.gain = 0,
    this.gainKey = 0,
    this.candy = Candy.purple,
  });
  final String label;
  final int value;
  final int gain;
  final int gainKey;
  final Candy candy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: candy == Candy.purple ? AppColors.surface : candy.light,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: candy == Candy.purple ? AppColors.border : candy.base.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              Text(label, style: AppText.label(10, color: candy == Candy.purple ? AppColors.inkSoft : candy.dark)),
              TweenAnimationBuilder<int>(
                tween: IntTween(end: value),
                duration: const Duration(milliseconds: 300),
                builder: (_, v, _) => Text('$v', style: AppText.display(22)),
              ),
            ],
          ),
        ),
        if (gain > 0)
          Positioned(
            right: 10,
            top: -4,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(gainKey),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, t, _) => Opacity(
                opacity: 1 - t,
                child: Transform.translate(
                  offset: Offset(0, -24 * t),
                  child: Text('+$gain', style: AppText.display(15, color: Candy.green.dark)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.value, required this.size});
  final int value;
  final double size;

  /// (fill, text) per power of two: warm greys first, then rising through the accents.
  static const _ramp = <(Color, Color)>[
    (Color(0xFFEEEBE4), AppColors.ink), // 2
    (Color(0xFFE2DCCE), AppColors.ink), // 4
    (Color(0xFFF7C79E), AppColors.ink), // 8
    (Color(0xFFE4572E), Colors.white), // 16
    (Color(0xFFE5484D), Colors.white), // 32
    (Color(0xFFD9577E), Colors.white), // 64
    (Color(0xFF8E5BA8), Colors.white), // 128
    (Color(0xFF2D5BD3), Colors.white), // 256
    (Color(0xFF0F9F95), Colors.white), // 512
    (Color(0xFFE9B23D), AppColors.ink), // 1024
    (AppColors.ink, Colors.white), // 2048+
  ];

  @override
  Widget build(BuildContext context) {
    final idx = (math.log(value) / math.ln2).round() - 1;
    final (fill, fg) = _ramp[idx.clamp(0, _ramp.length - 1)];
    final digits = '$value'.length;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, borderRadius: BorderRadius.circular(size * 0.14)),
      child: Text(
        '$value',
        maxLines: 1,
        style: AppText.display(size * (digits <= 2 ? 0.44 : (digits == 3 ? 0.36 : 0.28)), color: fg),
      ),
    );
  }
}
