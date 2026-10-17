import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/celebrations.dart';
import '../../core/ui/confetti.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/pressable.dart';
import '../../services/api_client.dart';
import '../../services/content_repo.dart';
import '../../services/services.dart';
import '../../state/player.dart';
import 'game_type.dart';
import 'results_overlay.dart';

/// Outcome reported by a game when the round ends.
class RoundResult {
  RoundResult({
    required this.won,
    required this.stars,
    required this.submission,
    this.mistakes = 0,
    this.detail,
    this.shareGrid,
  });
  final bool won;
  final int stars;
  final Map<String, dynamic> submission;
  final int mistakes;

  /// Short, game-specific line for the results card (e.g. "Par 4 • You 5").
  final String? detail;

  /// Optional spoiler-free emoji summary for sharing (e.g. Word Connect guess colours).
  final String? shareGrid;
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

  /// Ticks once a second for the timer pill.
  final ValueNotifier<Duration> clock = ValueNotifier(Duration.zero);
  AppLifecycleListener? _lifecycle;
  bool _pausedInBackground = false;

  /// Elapsed play time; screens rebuild every second for the timer pill.
  Duration get elapsed => stopwatch.elapsed;

  void startFlow() {
    stopwatch.start();
    // Time in the background never counts towards the puzzle clock (stats, daily score).
    _lifecycle = AppLifecycleListener(
      onHide: () {
        if (stopwatch.isRunning) {
          _pausedInBackground = true;
          stopwatch.stop();
        }
      },
      onShow: () {
        if (_pausedInBackground) {
          _pausedInBackground = false;
          resumeClock();
        }
      },
    );
    // Only the timer pill listens to this; the board itself never rebuilds per second.
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !finished) clock.value = stopwatch.elapsed;
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
    clock.dispose();
    _lifecycle?.dispose();
    confetti.dispose();
    super.dispose();
  }

  void pauseClock() => stopwatch.stop();
  void resumeClock() {
    if (!finished) stopwatch.start();
  }

  /// Consumes a hint token, or offers ways to get more. Returns true if granted.
  Future<bool> requestHint() async {
    if (finished) return false;
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
      final levelBefore = s.player.data.playerLevel;
      final xpBefore = s.player.data.xp;
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
          s.player.addXp(15 + 5 * r.stars);
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
        xpGained: s.player.data.xp - xpBefore,
      );
      if (!mounted) return;
      if (s.player.data.playerLevel > levelBefore) await showLevelUp(context, s.player.data.playerLevel);
      if (!mounted) return;
      unawaited(s.growth.onWin(stars: r.stars));
      if (request.source == PlaySource.daily) await _offerReminders();
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

  /// After the first daily win, offer a reminder once: the strongest retention lever we have.
  Future<void> _offerReminders() async {
    final s = context.services;
    const key = 'growth.reminderOffered';
    if (s.player.data.settings.reminders || (s.prefs.getBool(key) ?? false)) return;
    await s.prefs.setBool(key, true);
    if (!mounted) return;
    final yes = await confirmDialog(
      context,
      title: 'Keep your streak!',
      message: 'Want a gentle nudge when new puzzles are ready? One reminder a day, no spam.',
      yes: 'Remind me',
      no: 'Not now',
      candy: Candy.green,
    );
    if (!yes || !mounted) return;
    if (await s.reminders.requestPermission()) {
      s.player.updateSettings((x) => x.reminders = true);
      unawaited(
        s.api
            .updatePreferences({
              'notificationsEnabled': true,
              'reminderTime': '${s.player.data.settings.reminderHour.toString().padLeft(2, '0')}:00',
            })
            .catchError((Object _) {}),
      );
      if (mounted) {
        toast(
          context,
          'Reminder set for ${s.player.data.settings.reminderHour}:00',
          icon: Icons.notifications_active_rounded,
        );
      }
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
    this.roundOver = false,
    this.clock,
  });

  /// Live play time from [GameFlow.clock]; when given, only the timer pill rebuilds.
  final ValueListenable<Duration>? clock;

  final PlayRequest request;
  final Widget body;
  final Widget? status;
  final Widget? toolbar;
  final VoidCallback? onHint;
  final Duration elapsed;
  final ConfettiController? confetti;
  final bool showTimer;

  /// True once the round has ended (results pending): leaving can no longer forfeit it.
  final bool roundOver;

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
        backgroundColor: AppColors.bg,
        body: CandyBackground(
          gradient: AppColors.nightBg,
          density: 0,
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
                            candy: Candy.ink,
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
                                    stroke: const Color(0xFF172873),
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _Tag(switch (request.source) {
                                      PlaySource.daily => 'Daily',
                                      PlaySource.level => 'Journey',
                                      PlaySource.quick => 'Practice',
                                    }, c),
                                    const SizedBox(width: 6),
                                    _Tag(request.difficulty.label, request.difficulty.candy),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (showTimer)
                            clock == null
                                ? _TimerPill(elapsed)
                                : ValueListenableBuilder<Duration>(
                                    valueListenable: clock!,
                                    builder: (_, d, _) => _TimerPill(d),
                                  ),
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
                    if (status != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        // Cream bubble keeps instructions readable over the sky.
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8EA),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: status,
                        ),
                      ),
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
    if (roundOver) return;
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.light, borderRadius: BorderRadius.circular(8)),
    child: Text(
      text,
      style: AppText.body(11, color: c.dark, weight: FontWeight.w700),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.inkSoft, size: 16),
          const SizedBox(width: 5),
          Text(t, style: AppText.display(15).copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
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
    final c = active
        ? candy == Candy.white
              ? Candy.purple
              : candy
        : Candy.white;
    final fill = active ? c.light : AppColors.surface;
    final fg = onTap == null ? AppColors.inkFaint : (active ? c.dark : AppColors.ink);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Semantics(
          button: true,
          enabled: onTap != null,
          selected: active,
          label: label,
          excludeSemantics: true,
          child: Pressable(
            onTap: onTap,
            scale: 0.96,
            sound: Sfx.tap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 58,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: active ? c.base.withValues(alpha: 0.45) : AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 21),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    style: AppText.body(11, color: fg, weight: FontWeight.w700),
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
