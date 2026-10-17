import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/game_cover.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/panels.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/levels.dart';
import '../../state/player.dart';
import '../profile/invite.dart';
import '../rewards/rewards.dart';
import '../shop/shop_sheets.dart';

export '../../core/ui/game_cover.dart' show GameBadge;

const _weekdays = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
const _months = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', //
  'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
];
const _flame = Color(0xFFE4572E);

/// Issue number of today's puzzle set (No. 1 = launch day), like a daily paper.
int issueNumber(DateTime now) => now.toUtc().difference(DateTime.utc(2026, 1, 1)).inDays + 1;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _offeredLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Greet returning players with the login calendar once per day.
    if (!_offeredLogin && context.player.canClaimLogin && context.player.data.onboarded) {
      _offeredLogin = true;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) showLoginCalendar(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final d = p.data;
    final now = DateTime.now();
    final solved = GameType.values.where(p.dailyCompleted).length;
    final greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 18 => 'Good afternoon',
      _ => 'Good evening',
    };
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children:
            [
                  const _Masthead(),
                  const SizedBox(height: 18),
                  Text(
                    '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day} · NO. ${issueNumber(now)}',
                    style: AppText.label(11),
                  ),
                  const SizedBox(height: 6),
                  Text('$greeting, ${d.displayName}.', style: AppText.body(15, color: AppColors.inkSoft)),
                  Text("Today's puzzles", style: AppText.display(30)),
                  const SizedBox(height: 12),
                  _Progress(solved: solved),
                  const SizedBox(height: 16),
                  for (final g in GameType.values) ...[
                    _PuzzleRow(game: g, done: p.dailyCompleted(g)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                  const _StreakCard(),
                  const SectionTitle('Your journey'),
                  _JourneyCard(level: d.currentLevel, spec: Campaign.level(d.currentLevel)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _RewardTile(
                          art: ArtKind.chest,
                          title: 'Daily gift',
                          subtitle: p.canClaimLogin ? 'Ready to open' : 'Back tomorrow',
                          ready: p.canClaimLogin,
                          onTap: () => showLoginCalendar(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RewardTile(
                          art: ArtKind.star,
                          title: 'Lucky spin',
                          subtitle: p.canFreeSpin ? 'Free spin ready' : 'Spin with an ad',
                          ready: p.canFreeSpin,
                          onTap: () => context.push('/spin'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const InviteCard(compact: true),
                  SectionTitle(
                    'Practice',
                    trailing: Text('No lives needed', style: AppText.body(13, color: AppColors.inkSoft)),
                  ),
                  SizedBox(
                    height: 148,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount: GameType.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _PracticeCard(game: GameType.values[i]),
                    ),
                  ),
                ]
                .animate(interval: 40.ms)
                .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}

/// Serif wordmark, streak and coins, avatar with level ring — over a hairline rule.
class _Masthead extends StatelessWidget {
  const _Masthead();

  @override
  Widget build(BuildContext context) {
    final d = context.player.data;
    return Container(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink)),
      ),
      child: Row(
        children: [
          Text('Quintile', style: AppText.display(30)),
          const Spacer(),
          _Chip(
            icon: const Icon(Icons.local_fire_department_rounded, color: _flame, size: 18),
            value: '${d.streak}',
            onTap: () => context.go('/daily'),
            label: '${d.streak} day streak',
          ),
          const SizedBox(width: 6),
          _Chip(
            icon: const GameArt(ArtKind.coin, size: 16),
            value: _short(d.coins),
            onTap: () => context.go('/shop'),
            label: '${d.coins} coins',
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: () => context.push('/profile'),
            semanticLabel: 'Profile, level ${d.playerLevel}',
            child: SizedBox.square(
              dimension: 42,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 42,
                    child: CircularProgressIndicator(
                      value: d.levelProgress,
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      color: AppColors.accent,
                      backgroundColor: AppColors.divider,
                    ),
                  ),
                  Avatar(index: d.avatar, size: 32),
                  Positioned(
                    right: -4,
                    bottom: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.bg, width: 1.5),
                      ),
                      child: Text(
                        '${d.playerLevel}',
                        style: AppText.body(10, color: AppColors.surface, weight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(int n) => n >= 10000 ? '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k' : '$n';
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.value, required this.label, this.onTap});
  final Widget icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, a) => SlideTransition(
              position: Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: AppText.body(14, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Five ink segments for today's five puzzles.
class _Progress extends StatelessWidget {
  const _Progress({required this.solved});
  final int solved;

  @override
  Widget build(BuildContext context) {
    final all = solved == GameType.values.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < 5; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < solved ? AppColors.ink : AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < 4) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                all ? 'A perfect day. +300 coins earned.' : '$solved of 5 solved · finish all five for +300 coins',
                style: AppText.body(13, color: AppColors.inkSoft),
              ),
            ),
            if (all) const GameArt(ArtKind.chest, size: 22),
          ],
        ),
      ],
    );
  }
}

/// One of today's puzzles: a flat colour block with its illustration and a pill.
class _PuzzleRow extends StatelessWidget {
  const _PuzzleRow({required this.game, required this.done});
  final GameType game;
  final bool done;

  static String _clock(int ms) => '${ms ~/ 60000}:${((ms ~/ 1000) % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = game.candy;
    final best = context.player.data.stats[game.wire]?.bestMs;
    final onGold = c == Candy.gold;
    return Pressable(
      onTap: () => context.push('/play/daily/${game.name}'),
      scale: 0.98,
      semanticLabel: '${game.title}, ${done ? 'solved' : 'play'}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: done ? 0.62 : 1,
        child: Container(
          height: 86,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: c.base, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              SizedBox.square(dimension: 58, child: GameArtwork(game: game, radius: 12, compact: true)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: AppText.display(20, color: c.on)),
                    const SizedBox(height: 2),
                    Text(
                      done ? (best == null ? 'Solved today' : 'Solved · best ${_clock(best)}') : game.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(13, color: c.on.withValues(alpha: 0.85), weight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (done)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: c.on),
                  child: Icon(Icons.check_rounded, color: c.base, size: 22),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: onGold ? AppColors.ink : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Play',
                    style: AppText.body(14, color: onGold ? AppColors.surface : AppColors.ink, weight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Streak with this week's days — the reason to come back tomorrow.
class _StreakCard extends StatelessWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context) {
    final d = context.player.data;
    final playedToday = d.lastStreakDate == utcDate();
    final now = DateTime.now();
    final covered = <int>{};
    if (d.streak > 0 && d.lastStreakDate != null) {
      final endOffset = playedToday ? 0 : 1;
      for (var i = 0; i < d.streak && i + endOffset < 7; i++) {
        covered.add(i + endOffset);
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              playedToday
                  ? const Icon(Icons.local_fire_department_rounded, color: _flame, size: 40)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.94, end: 1.06, duration: 900.ms, curve: Curves.easeInOut)
                  : const Icon(Icons.local_fire_department_rounded, color: AppColors.inkFaint, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.streak == 0 ? 'Start your streak' : '${d.streak}-day streak', style: AppText.display(21)),
                    Text(
                      playedToday
                          ? 'Done for today. See you tomorrow!'
                          : d.streak == 0
                          ? 'Solve any daily puzzle to light the flame.'
                          : 'Solve one puzzle today to keep it going.',
                      style: AppText.body(13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (d.bestStreak > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('BEST', style: AppText.label(10)),
                    Text('${d.bestStreak}', style: AppText.display(20)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var back = 6; back >= 0; back--)
                _Day(
                  label: 'MTWTFSS'[now.subtract(Duration(days: back)).weekday - 1],
                  done: covered.contains(back),
                  today: back == 0,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({required this.label, required this.done, required this.today});
  final String label;
  final bool done;
  final bool today;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: AppText.body(11, color: today ? AppColors.ink : AppColors.inkFaint, weight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? _flame : AppColors.bg,
          border: today && !done ? Border.all(color: _flame, width: 2) : null,
        ),
        child: done ? const Icon(Icons.check_rounded, color: AppColors.surface, size: 18) : null,
      ),
    ],
  );
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.level, required this.spec});
  final int level;
  final LevelSpec spec;

  @override
  Widget build(BuildContext context) {
    final world = Campaign.worldOf(level);
    final p = context.player;
    const per = Campaign.levelsPerWorld;
    final inWorld = (level - 1) % per;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              GameBadge(game: spec.game, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      world.name.toUpperCase(),
                      style: AppText.label(10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('Level $level', style: AppText.display(22)),
                    Text(
                      '${spec.game.title} · ${spec.difficulty.label}',
                      style: AppText.body(13, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const GameArt(ArtKind.heart, size: 18),
              const SizedBox(width: 4),
              Text(p.unlimitedHearts ? '∞' : '${p.data.hearts}', style: AppText.body(15, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: inWorld / per,
                        minHeight: 6,
                        color: AppColors.ink,
                        backgroundColor: AppColors.divider,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$inWorld of $per levels in this world', style: AppText.body(12, color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              CandyButton(
                label: 'Play',
                icon: Icons.play_arrow_rounded,
                candy: Candy.ink,
                height: 46,
                width: 104,
                depth: 0,
                onTap: () async {
                  if (!context.services.player.canPlayLevel) {
                    await showOutOfLives(context);
                    return;
                  }
                  if (context.mounted) context.push('/play/level/$level');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.art,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.ready = false,
  });
  final ArtKind art;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool ready;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    semanticLabel: title,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: ready ? Candy.gold.light : AppColors.surface,
        border: Border.all(color: ready ? Candy.gold.base : AppColors.border, width: ready ? 1.5 : 1),
      ),
      child: Row(
        children: [
          GameArt(art, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.display(15)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(12, color: ready ? Candy.gold.dark : AppColors.inkSoft, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.game});
  final GameType game;

  @override
  Widget build(BuildContext context) {
    final won = context.player.data.stats[game.wire]?.won ?? 0;
    return Pressable(
      onTap: () => context.push('/play/quick/${game.name}'),
      scale: 0.96,
      semanticLabel: 'Practice ${game.title}',
      child: SizedBox(
        width: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 100, child: GameArtwork(game: game, radius: 16, compact: true)),
            const SizedBox(height: 8),
            Text(game.title, style: AppText.display(14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(won > 0 ? '$won won' : 'New', style: AppText.body(12, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
