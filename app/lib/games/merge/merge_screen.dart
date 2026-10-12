import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/outlined_text.dart';
import '../../services/content_repo.dart';
import '../common/game_flow.dart';
import '../common/results_overlay.dart';
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
    if (stars > 0 && (reachedTarget || request.source != PlaySource.daily)) {
      finish(RoundResult(
        won: true,
        stars: stars,
        submission: submission,
        detail: 'Best tile $max • Score ${game.score}',
      ));
    } else {
      finish(
        RoundResult(won: false, stars: 0, submission: submission),
        // Continues alter the board, so they're disabled for the leaderboard daily.
        onContinue: request.source == PlaySource.daily ? null : _clearSmallest,
      );
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
          }
      ];
      final vals = [for (final i in idx) if (g[i] != 0) g[i]];
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
        confetti: confetti,
        onHint: () async {
          if (await requestHint()) setState(() => _suggestion = _bestMove());
        },
        status: Column(children: [
          Row(children: [
            Expanded(child: _ScoreBox(label: 'SCORE', value: game.score, gain: _lastScoreGain, gainKey: _gainKey)),
            const SizedBox(width: 10),
            Expanded(child: _ScoreBox(label: 'GOAL', value: target, candy: Candy.gold)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(children: [
              Container(height: 16, color: Colors.white12),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                widthFactor: progress,
                child: Container(height: 16, decoration: BoxDecoration(gradient: Candy.green.face)),
              ),
            ]),
          ),
        ]),
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
                  _move(v.dx.abs() > v.dy.abs()
                      ? (v.dx > 0 ? MoveDir.right : MoveDir.left)
                      : (v.dy > 0 ? MoveDir.down : MoveDir.up));
                },
                child: BoardFrame(
                  candy: Candy.green,
                  child: LayoutBuilder(builder: (context, box) {
                    final n = game.size;
                    const gap = 8.0;
                    final cell = (box.maxWidth - gap * (n + 1)) / n;
                    Offset pos(int r, int c) => Offset(gap + c * (cell + gap), gap + r * (cell + gap));
                    return Stack(children: [
                      Container(
                        decoration: BoxDecoration(color: const Color(0xFFE6DDF7), borderRadius: BorderRadius.circular(12)),
                      ),
                      for (var r = 0; r < n; r++)
                        for (var c = 0; c < n; c++)
                          Positioned(
                            left: pos(r, c).dx,
                            top: pos(r, c).dy,
                            width: cell,
                            height: cell,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFD3C6EE),
                                borderRadius: BorderRadius.circular(cell * 0.18),
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
                            tween: Tween(begin: t.spawnedThisMove ? 0.0 : (t.mergedThisMove ? 1.25 : 1.0), end: 1),
                            duration: Duration(milliseconds: t.spawnedThisMove ? 220 : 260),
                            curve: t.spawnedThisMove ? Curves.easeOutBack : Curves.elasticOut,
                            builder: (_, s, child) => Transform.scale(scale: s, child: child),
                            child: _TileView(value: t.value, size: cell),
                          ),
                        ),
                    ]);
                  }),
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
                  ? Text('Swipe to merge matching tiles', key: const ValueKey('t'), style: AppText.body(15, color: Colors.white70))
                  : Row(
                      key: ValueKey(_suggestion),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Try swiping', style: AppText.body(16, color: Colors.white)),
                        const SizedBox(width: 8),
                        Transform.rotate(
                          angle: switch (_suggestion!) {
                            MoveDir.right => 0,
                            MoveDir.down => math.pi / 2,
                            MoveDir.left => math.pi,
                            MoveDir.up => -math.pi / 2,
                          },
                          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 36),
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
  const _ScoreBox({required this.label, required this.value, this.gain = 0, this.gainKey = 0, this.candy = Candy.purple});
  final String label;
  final int value;
  final int gain;
  final int gainKey;
  final Candy candy;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          gradient: candy.face,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: candy.dark, width: 2),
          boxShadow: [BoxShadow(color: candy.dark, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Text(label, style: AppText.body(11, color: Colors.white70, weight: FontWeight.w800)),
          TweenAnimationBuilder<int>(
            tween: IntTween(end: value),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, _) => Text('$v', style: AppText.display(24)),
          ),
        ]),
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
                child: OutlinedText('+$gain', size: 18, stroke: Candy.green.dark),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _TileView extends StatelessWidget {
  const _TileView({required this.value, required this.size});
  final int value;
  final double size;

  static const _ramp = [
    Candy(Color(0xFFFFFFFF), Color(0xFFF1ECFF), Color(0xFFC6B9EA)), // 2
    Candy(Color(0xFFFFF6D6), Color(0xFFFFE7A3), Color(0xFFD9B456)), // 4
    Candy.orange, // 8
    Candy.red, // 16
    Candy.pink, // 32
    Candy.purple, // 64
    Candy.blue, // 128
    Candy.teal, // 256
    Candy.green, // 512
    Candy.gold, // 1024
    Candy(Color(0xFFFFF59A), Color(0xFFFF9D00), Color(0xFF9E5200)), // 2048+
  ];

  @override
  Widget build(BuildContext context) {
    final idx = (math.log(value) / math.ln2).round() - 1;
    final c = _ramp[idx.clamp(0, _ramp.length - 1)];
    final light = idx <= 1;
    final digits = '$value'.length;
    return Container(
      decoration: BoxDecoration(
        gradient: c.face,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(color: c.dark, width: 2),
        boxShadow: [
          BoxShadow(color: c.dark, offset: Offset(0, size * 0.06)),
          if (value >= 128) BoxShadow(color: c.base.withValues(alpha: 0.6), blurRadius: 14),
        ],
      ),
      child: Stack(children: [
        Positioned(
          left: size * 0.12,
          right: size * 0.12,
          top: size * 0.06,
          height: size * 0.3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
        Center(
          child: light
              ? Text('$value', style: AppText.display(size * (digits <= 2 ? 0.46 : 0.34), color: AppColors.royal))
              : OutlinedText('$value', size: size * (digits <= 2 ? 0.46 : (digits == 3 ? 0.36 : 0.28)), stroke: c.dark, shadow: false),
        ),
      ]),
    );
  }
}
