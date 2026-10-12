import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/panels.dart';
import '../../services/content_repo.dart';
import '../../services/services.dart';
import '../../state/player.dart';
import 'game_flow.dart';
import 'game_type.dart';

enum ResultAction { next, retry, home, leaderboard, continuePlay }

String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

Future<ResultAction?> showResults(
  BuildContext context, {
  required PlayRequest request,
  required RoundResult result,
  required Duration elapsed,
  required int hintsUsed,
  LevelReward? reward,
  int dailyCoins = 0,
  Future<Map<String, dynamic>?>? dailySubmit,
}) {
  final title = switch (request.source) {
    PlaySource.level => result.stars == 3 ? 'Sweet!' : (result.stars == 2 ? 'Delicious!' : 'Level Clear!'),
    PlaySource.daily => 'Daily Done!',
    PlaySource.quick => 'Solved!',
  };
  return showCandyDialog<ResultAction>(
    context,
    title: title,
    ribbon: request.game.candy,
    dismissible: false,
    showClose: false,
    builder: (ctx) => _ResultsBody(
      request: request,
      result: result,
      elapsed: elapsed,
      reward: reward,
      dailyCoins: dailyCoins,
      dailySubmit: dailySubmit,
      hintsUsed: hintsUsed,
    ),
  );
}

class _ResultsBody extends StatefulWidget {
  const _ResultsBody({
    required this.request,
    required this.result,
    required this.elapsed,
    required this.hintsUsed,
    this.reward,
    this.dailyCoins = 0,
    this.dailySubmit,
  });

  final PlayRequest request;
  final RoundResult result;
  final Duration elapsed;
  final int hintsUsed;
  final LevelReward? reward;
  final int dailyCoins;
  final Future<Map<String, dynamic>?>? dailySubmit;

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> with TickerProviderStateMixin {
  late final AnimationController _stars = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _count = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  bool _doubled = false;
  final _played = <int>{};

  int get _coins => widget.reward?.coins ?? (widget.dailyCoins > 0 ? widget.dailyCoins : 10 + 5 * widget.result.stars);

  @override
  void initState() {
    super.initState();
    _stars.addListener(() {
      for (var i = 0; i < widget.result.stars; i++) {
        if (_stars.value >= 0.15 + i * 0.27 && _played.add(i)) {
          Audio.instance.play(Sfx.star);
          Audio.instance.haptic(HapticKind.medium);
        }
      }
    });
    _stars.forward().then((_) {
      if (mounted) {
        _count.forward();
        Audio.instance.play(Sfx.coin);
      }
    });
  }

  @override
  void dispose() {
    _stars.dispose();
    _count.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _shine,
                builder: (_, _) => Transform.rotate(
                  angle: _shine.value * 2 * math.pi,
                  child: CustomPaint(size: const Size(240, 240), painter: _RaysPainter(r.game.candy.light)),
                ),
              ),
              AnimatedBuilder(
                animation: _stars,
                builder: (_, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [for (var i = 0; i < 3; i++) _star(i)],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (widget.result.detail != null)
          Text(widget.result.detail!, textAlign: TextAlign.center, style: AppText.body(15, color: AppColors.inkSoft)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Stat(icon: Icons.timer_rounded, label: 'Time', value: _fmt(widget.elapsed))),
            const SizedBox(width: 8),
            Expanded(child: _Stat(icon: Icons.lightbulb_rounded, label: 'Hints', value: '${widget.hintsUsed}')),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedBuilder(
                animation: _count,
                builder: (_, _) => _Stat(
                  art: ArtKind.coin,
                  label: 'Coins',
                  value: '+${(_coins * (_doubled ? 2 : 1) * Curves.easeOut.transform(_count.value)).round()}',
                ),
              ),
            ),
          ],
        ),
        if (widget.dailySubmit != null) ...[
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>?>(
            future: widget.dailySubmit,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Text('Submitting your score…', style: AppText.body(14, color: AppColors.inkSoft));
              }
              final d = snap.data;
              if (d == null || d['result'] != 'SOLVED') {
                return Text('Offline — your streak is saved on this device.',
                    textAlign: TextAlign.center, style: AppText.body(14, color: AppColors.inkSoft));
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF3EAFF), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const GameArt(ArtKind.crown, size: 28),
                    const SizedBox(width: 8),
                    Text('Score ${d['score']}', style: AppText.display(20, color: AppColors.ink)),
                    if (d['rank'] != null) ...[
                      const SizedBox(width: 12),
                      Text('Rank #${d['rank']}', style: AppText.display(20, color: AppColors.royal)),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 16),
        if (!_doubled && widget.request.source == PlaySource.level)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CandyButton(
              label: 'Double coins',
              icon: Icons.ondemand_video_rounded,
              candy: Candy.blue,
              height: 52,
              onTap: () async {
                final s = context.services;
                final ok = await s.ads.showRewarded('double_coins');
                if (ok && mounted) {
                  s.player.addCoins(_coins);
                  setState(() => _doubled = true);
                  _count.forward(from: 0);
                  Audio.instance.play(Sfx.coin);
                } else if (context.mounted) {
                  toast(context, 'No ad available right now');
                }
              },
            ),
          ),
        Row(
          children: [
            CandyIconButton(
              icon: Icons.replay_rounded,
              candy: Candy.orange,
              size: 58,
              semanticLabel: 'Replay',
              onTap: () => Navigator.pop(context, ResultAction.retry),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: switch (r.source) {
                PlaySource.level => CandyButton(
                    label: 'Next Level',
                    candy: Candy.green,
                    height: 62,
                    pulse: true,
                    onTap: () => Navigator.pop(context, ResultAction.next),
                  ),
                PlaySource.daily => CandyButton(
                    label: 'Leaderboard',
                    candy: Candy.green,
                    height: 62,
                    onTap: () => Navigator.pop(context, ResultAction.leaderboard),
                  ),
                PlaySource.quick => CandyButton(
                    label: 'Continue',
                    candy: Candy.green,
                    height: 62,
                    onTap: () => Navigator.pop(context, ResultAction.home),
                  ),
              },
            ),
            const SizedBox(width: 10),
            CandyIconButton(
              icon: Icons.home_rounded,
              candy: Candy.purple,
              size: 58,
              semanticLabel: 'Home',
              onTap: () => Navigator.pop(context, ResultAction.home),
            ),
          ],
        ),
      ],
    );
  }

  Widget _star(int i) {
    final earned = i < widget.result.stars;
    final start = 0.15 + i * 0.27;
    final t = ((_stars.value - start) / 0.3).clamp(0.0, 1.0);
    final scale = earned ? Curves.elasticOut.transform(t) : 1.0;
    final size = i == 1 ? 84.0 : 64.0;
    return Padding(
      padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0, left: 4, right: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          GameArt(ArtKind.starEmpty, size: size),
          if (earned) Transform.scale(scale: scale, child: GameArt(ArtKind.star, size: size)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({this.icon, this.art, required this.label, required this.value});
  final IconData? icon;
  final ArtKind? art;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.panelEdge, width: 2),
      ),
      child: Column(children: [
        if (art != null) GameArt(art!, size: 24) else Icon(icon, color: AppColors.royal, size: 22),
        const SizedBox(height: 2),
        FittedBox(child: Text(value, style: AppText.display(20, color: AppColors.ink))),
        Text(label, style: AppText.body(11, color: AppColors.inkSoft)),
      ]),
    );
  }
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..shader = RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)])
          .createShader(Rect.fromCircle(center: c, radius: size.width / 2));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.11) * size.width, c.dy + math.sin(a - 0.11) * size.width)
        ..lineTo(c.dx + math.cos(a + 0.11) * size.width, c.dy + math.sin(a + 0.11) * size.width)
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => false;
}

Future<ResultAction?> showFail(BuildContext context,
    {required PlayRequest request, required bool canContinue, required int continueCost}) {
  return showCandyDialog<ResultAction>(
    context,
    title: request.game == GameType.merge ? 'Out of moves!' : 'So close!',
    ribbon: Candy.red,
    dismissible: false,
    showClose: false,
    builder: (ctx) {
      final s = ctx.services;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BrokenHeart(),
          const SizedBox(height: 8),
          Text(
            request.source == PlaySource.level ? 'Keep going or you\'ll lose a life.' : 'Don\'t give up now!',
            textAlign: TextAlign.center,
            style: AppText.body(17, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          if (canContinue) ...[
            CandyButton(
              label: 'Continue  •  $continueCost',
              candy: Candy.green,
              height: 60,
              pulse: true,
              trailing: const GameArt(ArtKind.gem, size: 26),
              onTap: () {
                if (s.player.spendGems(continueCost)) {
                  Navigator.pop(ctx, ResultAction.continuePlay);
                } else {
                  toast(ctx, 'Not enough gems — visit the Shop');
                }
              },
            ),
            const SizedBox(height: 10),
            CandyButton(
              label: 'Watch ad to continue',
              icon: Icons.ondemand_video_rounded,
              candy: Candy.blue,
              height: 54,
              onTap: () async {
                if (await s.ads.showRewarded('continue') && ctx.mounted) {
                  Navigator.pop(ctx, ResultAction.continuePlay);
                } else if (ctx.mounted) {
                  toast(ctx, 'No ad available right now');
                }
              },
            ),
            const SizedBox(height: 10),
          ],
          Row(children: [
            Expanded(
              child: CandyButton(
                  label: 'Retry', candy: Candy.orange, height: 54, onTap: () => Navigator.pop(ctx, ResultAction.retry)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: CandyButton(
                  label: 'Give up', candy: Candy.grey, height: 54, onTap: () => Navigator.pop(ctx, ResultAction.home)),
            ),
          ]),
        ],
      );
    },
  );
}

class _BrokenHeart extends StatefulWidget {
  const _BrokenHeart();
  @override
  State<_BrokenHeart> createState() => _BrokenHeartState();
}

class _BrokenHeartState extends State<_BrokenHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final shake = math.sin(_c.value * math.pi * 8) * (1 - _c.value) * 10;
        return Transform.translate(
          offset: Offset(shake, 0),
          child: const Stack(alignment: Alignment.center, children: [
            GameArt(ArtKind.heart, size: 90),
            OutlinedText('-1', size: 30, stroke: Color(0xFF9E0A33)),
          ]),
        );
      },
    );
  }
}

/// Small helper reused by games to show the "panel" around a board.
class BoardFrame extends StatelessWidget {
  const BoardFrame({super.key, required this.child, this.candy = Candy.purple});
  final Widget child;
  final Candy candy;

  @override
  Widget build(BuildContext context) =>
      CandyPanel(rim: candy, padding: const EdgeInsets.all(8), radius: 20, child: child);
}
