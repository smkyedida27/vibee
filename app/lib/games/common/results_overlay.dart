import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/game_cover.dart';
import '../../features/shop/shop_sheets.dart';
import '../../services/growth.dart';
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
  int xpGained = 0,
}) {
  return showGeneralDialog<ResultAction>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Results',
    barrierColor: const Color(0xFF3A9CFF),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, _) => _ResultsBody(
      request: request,
      result: result,
      elapsed: elapsed,
      reward: reward,
      dailyCoins: dailyCoins,
      dailySubmit: dailySubmit,
      hintsUsed: hintsUsed,
      xpGained: xpGained,
    ),
    transitionBuilder: (ctx, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
          child: child,
        ),
      );
    },
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
    this.xpGained = 0,
  });

  final PlayRequest request;
  final RoundResult result;
  final Duration elapsed;
  final int hintsUsed;
  final LevelReward? reward;
  final int dailyCoins;
  final Future<Map<String, dynamic>?>? dailySubmit;
  final int xpGained;

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> with TickerProviderStateMixin {
  late final AnimationController _stars = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _count = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _doubled = false;
  final _played = <int>{};

  /// Coins actually granted for this round (a replayed daily grants none).
  int get _coins =>
      widget.reward?.coins ??
      (widget.request.source == PlaySource.daily ? widget.dailyCoins : 10 + 5 * widget.result.stars);

  Map<String, dynamic>? _submitted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.dailySubmit?.then((d) {
      if (mounted) setState(() => _submitted = d);
    });
  }

  Future<void> _share(BuildContext context) async {
    final s = context.services;
    final r = widget.request;
    final d = s.player.data;
    final rank = (_submitted?['rank'] as num?)?.toInt();
    final text = buildResultShare(
      game: r.game,
      daily: r.source == PlaySource.daily,
      stars: widget.result.stars,
      elapsed: widget.elapsed,
      hints: widget.hintsUsed,
      grid: widget.result.shareGrid,
      level: r.level,
      streak: r.source == PlaySource.daily ? d.streak : 0,
      rank: rank,
      inviteCode: s.growth.inviteCode,
      date: r.source == PlaySource.daily ? d.dailyDate : null,
    );
    await s.growth.shareText(context, text, kind: 'result_${r.source.name}');
  }

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
    super.dispose();
  }

  String get _headline {
    final stars = widget.result.stars;
    const top = ['Brilliant!', 'Flawless!', 'Superb!', 'Sharp!', 'Masterful!'];
    if (stars >= 3) return top[widget.request.game.index];
    if (stars == 2) return 'Great job!';
    return 'Solved!';
  }

  String get _kicker => switch (widget.request.source) {
    PlaySource.daily => 'DAILY ${widget.request.game.title.toUpperCase()}',
    PlaySource.level => 'LEVEL ${widget.request.level} · ${widget.request.game.title.toUpperCase()}',
    PlaySource.quick when widget.request.stage != null =>
      '${widget.request.game.title.toUpperCase()} · ${widget.request.difficulty.label.toUpperCase()} · LEVEL ${widget.request.stage}',
    PlaySource.quick => 'PRACTICE · ${widget.request.game.title.toUpperCase()}',
  };

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final c = r.game.candy;
    final d = context.player.data;
    final primary = switch (r.source) {
      PlaySource.level => ('Next level', ResultAction.next),
      PlaySource.daily => ('See leaderboard', ResultAction.leaderboard),
      PlaySource.quick when r.stage != null => ('Next level', ResultAction.next),
      PlaySource.quick => ('Continue', ResultAction.home),
    };
    return Material(
      type: MaterialType.transparency,
      child: CandyBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Row(
                children: [
                  Text(_kicker, style: AppText.label(11)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Home',
                    onPressed: () => Navigator.pop(context, ResultAction.home),
                    icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                  ),
                ],
              ),
              // Hero: the game's colour block with its artwork, the headline and stars.
              Container(
                height: 236,
                decoration: BoxDecoration(color: c.base, borderRadius: BorderRadius.circular(24)),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(child: GameArtwork(game: r.game, radius: 0, corner: true, compact: true)),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          Text(_headline, style: AppText.display(42, color: c.on))
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack, duration: 450.ms),
                          if (widget.result.detail != null)
                            Text(
                              widget.result.detail!,
                              style: AppText.body(15, color: c.on.withValues(alpha: 0.85), weight: FontWeight.w600),
                            ),
                          const SizedBox(height: 14),
                          AnimatedBuilder(
                            animation: _stars,
                            builder: (_, _) => Row(children: [for (var i = 0; i < 3; i++) _star(i)]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...[
                    Row(
                      children: [
                        Expanded(
                          child: _Stat(icon: Icons.timer_outlined, label: 'Time', value: _fmt(widget.elapsed)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Stat(
                            icon: Icons.lightbulb_outline_rounded,
                            label: 'Hints',
                            value: '${widget.hintsUsed}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _count,
                            builder: (_, _) => _Stat(
                              art: ArtKind.coin,
                              label: 'Coins',
                              value: _coins == 0
                                  ? '—'
                                  : '+${(_coins * (_doubled ? 2 : 1) * Curves.easeOut.transform(_count.value)).round()}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.xpGained > 0) ...[const SizedBox(height: 12), _XpRow(gained: widget.xpGained)],
                    if (widget.dailySubmit != null) ...[
                      const SizedBox(height: 12),
                      FutureBuilder<Map<String, dynamic>?>(
                        future: widget.dailySubmit,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return Text(
                              'Submitting your score…',
                              textAlign: TextAlign.center,
                              style: AppText.body(14, color: AppColors.inkSoft),
                            );
                          }
                          final sd = snap.data;
                          final ranked = sd != null && (sd['result'] == 'SOLVED' || sd['rank'] != null);
                          if (!ranked) {
                            final String msg;
                            if (sd == null) {
                              msg = "Couldn't reach the leaderboard — your streak is saved on this device.";
                            } else if (sd['counted'] == false) {
                              msg = 'Only your first attempt is ranked — nice practice run!';
                            } else if (sd['result'] == 'FAILED') {
                              // Only a continue past the mistake limit turns a solved board into FAILED.
                              msg = 'Solved with a continue — not ranked today, but your streak counts!';
                            } else {
                              msg = "This run couldn't be verified for the leaderboard, but your streak counts!";
                            }
                            return Text(
                              msg,
                              textAlign: TextAlign.center,
                              style: AppText.body(14, color: AppColors.inkSoft),
                            );
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("TODAY'S SCORE", style: AppText.label(10)),
                                      Text('${sd['score']}', style: AppText.display(26)),
                                    ],
                                  ),
                                ),
                                if (sd['rank'] != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('RANK', style: AppText.label(10)),
                                      Text('#${sd['rank']}', style: AppText.display(26, color: c.dark)),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    if (r.source == PlaySource.daily && d.streak > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE6DF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE4572E), size: 30)
                                .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                                .scaleXY(begin: 0.92, end: 1.08, duration: 700.ms, curve: Curves.easeInOut),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${d.streak}-day streak! Come back tomorrow to make it ${d.streak + 1}.',
                                style: AppText.body(14, weight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    CandyButton(
                      label: primary.$1,
                      candy: Candy.ink,
                      depth: 0,
                      height: 56,
                      onTap: () => Navigator.pop(context, primary.$2),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: CandyButton(
                            label: r.source == PlaySource.daily ? 'Share result' : 'Share',
                            icon: Icons.ios_share_rounded,
                            candy: Candy.white,
                            depth: 0,
                            height: 52,
                            onTap: () => _share(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CandyIconButton(
                          icon: Icons.replay_rounded,
                          candy: Candy.ink,
                          size: 52,
                          semanticLabel: 'Replay',
                          onTap: () => Navigator.pop(context, ResultAction.retry),
                        ),
                      ],
                    ),
                    if (!_doubled && r.source == PlaySource.level && _coins > 0) ...[
                      const SizedBox(height: 10),
                      CandyButton(
                        label: 'Watch an ad to double your coins',
                        icon: Icons.play_circle_outline_rounded,
                        candy: Candy.gold,
                        depth: 0,
                        height: 50,
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
                    ],
                  ]
                  .animate(interval: 60.ms, delay: 250.ms)
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
            ],
          ),
        ),
      ),
    );
  }

  /// Stars sit on the game-colour hero, so they use its readable "on" colour.
  Widget _star(int i) {
    final earned = i < widget.result.stars;
    final start = 0.15 + i * 0.27;
    final t = ((_stars.value - start) / 0.3).clamp(0.0, 1.0);
    final on = widget.request.game.candy.on;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.star_rounded, size: 40, color: on.withValues(alpha: 0.22)),
          if (earned)
            Transform.scale(
              scale: Curves.easeOutBack.transform(t),
              child: Icon(Icons.star_rounded, size: 40, color: on),
            ),
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
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (art != null) GameArt(art!, size: 24) else Icon(icon, color: AppColors.inkSoft, size: 20),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(value, style: AppText.display(20, color: AppColors.ink)),
          ),
          Text(
            label,
            style: AppText.body(11, color: AppColors.inkSoft, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

Future<ResultAction?> showFail(
  BuildContext context, {
  required PlayRequest request,
  required bool canContinue,
  required int continueCost,
}) {
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
              onTap: () async {
                if (await spendGemsFor(ctx, 'CONTINUE', continueCost) && ctx.mounted) {
                  Navigator.pop(ctx, ResultAction.continuePlay);
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
          Row(
            children: [
              Expanded(
                child: CandyButton(
                  label: 'Retry',
                  candy: Candy.orange,
                  height: 54,
                  onTap: () => Navigator.pop(ctx, ResultAction.retry),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CandyButton(
                  label: 'Give up',
                  candy: Candy.grey,
                  height: 54,
                  onTap: () => Navigator.pop(ctx, ResultAction.home),
                ),
              ),
            ],
          ),
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              const GameArt(ArtKind.heart, size: 84),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('-1', style: AppText.display(26, color: Colors.white)),
              ),
            ],
          ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

/// "+40 XP" with the level bar filling from where it was to where it is now.
class _XpRow extends StatelessWidget {
  const _XpRow({required this.gained});
  final int gained;

  @override
  Widget build(BuildContext context) {
    final d = context.player.data;
    final lo = PlayerData.xpForLevel(d.playerLevel), hi = PlayerData.xpForLevel(d.playerLevel + 1);
    final before = ((d.xp - gained - lo) / (hi - lo)).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: const Color(0xFFFBF0D6), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            children: [
              Text('+$gained XP', style: AppText.display(16, color: AppColors.primary)),
              const Spacer(),
              Text(
                'Level ${d.playerLevel}',
                style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: before, end: d.levelProgress),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: AppColors.primary,
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
