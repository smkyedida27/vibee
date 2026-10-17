import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/confetti.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/outlined_text.dart';
import '../../services/api_client.dart';
import '../../services/content_repo.dart';
import '../../services/services.dart';
import '../../state/player.dart';
import 'game_type.dart';
import 'results_overlay.dart';

/// Outcome reported by a game when the round ends.
class RoundResult {
  RoundResult({required this.won, required this.stars, required this.submission, this.mistakes = 0, this.detail});
  final bool won;
  final int stars;
  final Map<String, dynamic> submission;
  final int mistakes;

  /// Short, game-specific line for the results card (e.g. "Par 4 • You 5").
  final String? detail;
}

/// Shared lifecycle for all game screens: timing, hints, daily attempts, rewards,
/// results/fail overlays, continues and ad pacing.
mixin GameFlow<T extends StatefulWidget> on State<T> {
  PlayRequest get request;

  final Stopwatch stopwatch = Stopwatch();
  final ConfettiController confetti = ConfettiController();
  int hintsUsed = 0;
  int continuesUsed = 0;
  bool finished = false;
  Future<String?>? _attempt;
  Timer? _clockTick;

  /// Elapsed play time; screens rebuild every second for the timer pill.
  Duration get elapsed => stopwatch.elapsed;

  void startFlow() {
    stopwatch.start();
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !finished) setState(() {});
    });
    final s = context.services;
    s.analytics.puzzleStart(request.game.wire, request.source.name, request.difficulty.wire);
    final daily = request.daily;
    if (daily != null && daily.puzzleId != null) {
      _attempt = s.api
          .createAttempt(daily.puzzleId!)
          .then<String?>(
            (a) => '${a['attemptId']}',
            onError: (Object e) {
              debugPrint('attempt create failed (offline play continues): $e');
              return null;
            },
          );
    }
  }

  @override
  void dispose() {
    _clockTick?.cancel();
    confetti.dispose();
    super.dispose();
  }

  void pauseClock() => stopwatch.stop();
  void resumeClock() {
    if (!finished) stopwatch.start();
  }

  /// Consumes a hint token, or offers ways to get more. Returns true if granted.
  Future<bool> requestHint() async {
    final s = context.services;
    if (s.player.useHint()) {
      hintsUsed++;
      Audio.instance.fx(Sfx.unlock, HapticKind.medium);
      return true;
    }
    pauseClock();
    final got = await showCandyDialog<bool>(
      context,
      title: 'Need a hint?',
      ribbon: Candy.gold,
      builder: (ctx) => _HintOffer(onDone: (v) => Navigator.pop(ctx, v)),
    );
    resumeClock();
    if (got == true && mounted && s.player.useHint()) {
      hintsUsed++;
      return true;
    }
    return false;
  }

  /// Ends the round. For losses, [onContinue] (if given) lets the player buy one more chance.
  Future<void> finish(RoundResult r, {VoidCallback? onContinue}) async {
    if (finished) return;
    finished = true;
    stopwatch.stop();
    final s = context.services;
    final ms = stopwatch.elapsedMilliseconds;
    s.analytics.puzzleComplete(request.game.wire, request.source.name, won: r.won, ms: ms, hints: hintsUsed);

    if (r.won) {
      Audio.instance.fx(Sfx.win, HapticKind.heavy);
      confetti.burst();
      Future.delayed(const Duration(milliseconds: 350), () => confetti.rain());
      LevelReward? reward;
      var dailyCoins = 0;
      Future<Map<String, dynamic>?>? dailySubmit;
      switch (request.source) {
        case PlaySource.level:
          reward = s.player.completeLevel(level: request.level!, stars: r.stars, game: request.game, durationMs: ms);
        case PlaySource.daily:
          dailyCoins = s.player.completeDaily(request.game, durationMs: ms);
          dailySubmit = _submitDaily(r, ms);
        case PlaySource.quick:
          s.player.addCoins(10 + 5 * r.stars);
      }
      unawaited(s.sync.push());
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      final action = await showResults(
        context,
        request: request,
        result: r,
        elapsed: Duration(milliseconds: ms),
        reward: reward,
        dailyCoins: dailyCoins,
        dailySubmit: dailySubmit,
        hintsUsed: hintsUsed,
      );
      if (!mounted) return;
      await _afterRound(action, won: true);
    } else {
      Audio.instance.fx(Sfx.lose, HapticKind.heavy);
      final canContinue = onContinue != null && continuesUsed < 2;
      final action = await showFail(
        context,
        request: request,
        canContinue: canContinue,
        continueCost: Economy.continueGems * (continuesUsed + 1),
      );
      if (!mounted) return;
      if (action == ResultAction.continuePlay && onContinue != null) {
        continuesUsed++;
        finished = false;
        stopwatch.start();
        onContinue();
        return;
      }
      if (request.source == PlaySource.level) s.player.failLevel(game: request.game, durationMs: ms);
      unawaited(s.sync.push());
      await _afterRound(action, won: false);
    }
  }

  Future<Map<String, dynamic>?> _submitDaily(RoundResult r, int ms) async {
    final api = context.services.api;
    final id = await _attempt;
    if (id == null) return null;
    try {
      return await api.submitAttempt(id, submission: r.submission, hintsUsed: hintsUsed, clientDurationMs: ms);
    } on ApiException catch (e) {
      debugPrint('daily submit failed: $e');
      return null;
    }
  }

  Future<void> _afterRound(ResultAction? action, {required bool won}) async {
    final s = context.services;
    final router = GoRouter.of(context);
    // Interstitials only after a won level, never after a loss or on retry (docs/MONETIZATION.md).
    if (won &&
        request.source == PlaySource.level &&
        s.player.shouldShowInterstitial() &&
        action != ResultAction.retry) {
      s.player.markInterstitialShown();
      await s.ads.showInterstitial();
    }
    if (!mounted) return;
    switch (action) {
      case ResultAction.next:
        final next = (request.level ?? 0) + 1;
        if (!s.player.canPlayLevel) {
          router.go('/journey');
          return;
        }
        router.pushReplacement('/play/level/$next');
      case ResultAction.retry:
        if (request.source == PlaySource.level && !s.player.canPlayLevel) {
          router.go('/journey');
          return;
        }
        final path = GoRouterState.of(context).uri.toString();
        router.pushReplacement(path);
      case ResultAction.leaderboard:
        router.go('/leaders');
      case ResultAction.home:
      case ResultAction.continuePlay:
      case null:
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/');
        }
    }
  }
}

class _HintOffer extends StatelessWidget {
  const _HintOffer({required this.onDone});
  final ValueChanged<bool> onDone;

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const GameArt(ArtKind.bulb, size: 84),
        const SizedBox(height: 8),
        Text(
          'You\'re out of hints. Grab a pack and crack it!',
          textAlign: TextAlign.center,
          style: AppText.body(17, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        CandyButton(
          label: '3 hints  •  ${Economy.hintPackCoins}',
          candy: Candy.gold,
          height: 56,
          trailing: const GameArt(ArtKind.coin, size: 26),
          onTap: () {
            if (s.player.buyHintPack()) {
              Audio.instance.play(Sfx.coin);
              onDone(true);
            } else {
              toast(context, 'Not enough coins');
            }
          },
        ),
        const SizedBox(height: 12),
        CandyButton(
          label: 'Watch ad  •  +1 hint',
          candy: Candy.blue,
          icon: Icons.ondemand_video_rounded,
          height: 56,
          onTap: () async {
            final ok = await s.ads.showRewarded('hint');
            if (ok) {
              s.player.addHints(1);
              onDone(true);
            } else if (context.mounted) {
              toast(context, 'No ad available right now — try again soon');
            }
          },
        ),
      ],
    );
  }
}

/// Common game chrome: themed background, top bar with back/title/timer/hint,
/// optional status row, the board, and a bottom toolbar.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.request,
    required this.body,
    required this.elapsed,
    this.status,
    this.toolbar,
    this.onHint,
    this.confetti,
    this.showTimer = true,
  });

  final PlayRequest request;
  final Widget body;
  final Widget? status;
  final Widget? toolbar;
  final VoidCallback? onHint;
  final Duration elapsed;
  final ConfettiController? confetti;
  final bool showTimer;

  @override
  Widget build(BuildContext context) {
    final c = request.game.candy;
    final hints = context.player.data.hints;
    // System back runs the same confirm-and-forfeit flow as the on-screen back button.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave(context);
      },
      child: Scaffold(
        body: CandyBackground(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(c.dark, AppColors.night, 0.55)!,
              Color.lerp(c.base, AppColors.deep, 0.55)!,
              AppColors.night,
            ],
          ),
          density: 8,
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          CandyIconButton(
                            icon: Icons.arrow_back_rounded,
                            candy: Candy.purple,
                            size: 46,
                            semanticLabel: 'Back',
                            onTap: () => _confirmLeave(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: OutlinedText(
                                    request.title,
                                    size: 24,
                                    stroke: c.dark,
                                    textAlign: TextAlign.left,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    _Tag(request.game.title, c),
                                    const SizedBox(width: 6),
                                    _Tag(request.difficulty.label, request.difficulty.candy),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (showTimer) _TimerPill(elapsed),
                          if (onHint != null) ...[
                            const SizedBox(width: 8),
                            CandyIconButton(
                              icon: Icons.lightbulb_rounded,
                              candy: Candy.gold,
                              size: 46,
                              badge: '$hints',
                              semanticLabel: 'Hint, $hints left',
                              onTap: onHint,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (status != null) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: status),
                    Expanded(child: body),
                    if (toolbar != null) Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: toolbar),
                  ],
                ),
              ),
              if (confetti != null) Positioned.fill(child: ConfettiLayer(controller: confetti!)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await confirmDialog(
      context,
      title: 'Leave puzzle?',
      message: request.source == PlaySource.level && !context.player.unlimitedHearts
          ? 'Quitting a level costs a life.'
          : 'Your progress on this puzzle will be lost.',
      yes: 'Leave',
    );
    if (leave && context.mounted) {
      if (request.source == PlaySource.level) {
        context.services.player.failLevel(game: request.game, durationMs: elapsed.inMilliseconds);
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.c);
  final String text;
  final Candy c;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: c.base.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.light.withValues(alpha: 0.8)),
    ),
    child: Text(
      text,
      style: AppText.body(11, color: Colors.white, weight: FontWeight.w700),
    ),
  );
}

class _TimerPill extends StatelessWidget {
  const _TimerPill(this.d);
  final Duration d;

  @override
  Widget build(BuildContext context) {
    final t = '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xAA12052A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_rounded, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(t, style: AppText.display(16)),
        ],
      ),
    );
  }
}

/// Toolbar button with icon + caption (Undo, Erase, Notes, Shuffle…).
class ToolButton extends StatelessWidget {
  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.candy = Candy.white,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final Candy candy;

  @override
  Widget build(BuildContext context) {
    final c = active ? Candy.gold : candy;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CandyButton(
          label: '',
          height: 62,
          depth: 6,
          radius: 18,
          candy: c,
          sound: Sfx.tap,
          onTap: onTap,
          leading: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: c == Candy.white ? AppColors.royal : Colors.white, size: 22),
              Text(
                label,
                style: AppText.body(
                  11,
                  color: c == Candy.white ? AppColors.ink : Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
