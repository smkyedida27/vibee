import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/game_cover.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/panels.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/player.dart';
import '../rewards/rewards.dart';

export '../../core/ui/game_cover.dart' show GameBadge;

/// Issue number of today's puzzle set (No. 1 = launch day).
int issueNumber(DateTime now) => now.toUtc().difference(DateTime.utc(2026, 1, 1)).inDays + 1;

/// Picks a difficulty for [game] (showing progress and what unlocks next), then opens its levels.
Future<void> showPlayPicker(BuildContext context, GameType game) async {
  final picked = await showCandyDialog<Difficulty>(
    context,
    title: game.title,
    ribbon: game.candy,
    builder: (ctx) {
      final p = ctx.services.player;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GameBadge(game: game, size: 76),
          const SizedBox(height: 8),
          Text(
            game.tagline,
            textAlign: TextAlign.center,
            style: AppText.body(14, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          for (final d in Difficulty.values) _DifficultyRow(game: game, difficulty: d, player: p),
        ],
      );
    },
  );
  if (picked != null && context.mounted) context.push('/levels/${game.name}/${picked.name}');
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.game, required this.difficulty, required this.player});
  final GameType game;
  final Difficulty difficulty;
  final PlayerStore player;

  @override
  Widget build(BuildContext context) {
    final d = difficulty;
    final open = player.difficultyUnlocked(game, d);
    final stars = player.trackStars(game, d);
    final c = open ? d.candy : Candy.grey;
    final String sub;
    if (open) {
      sub = stars == 0 ? '100 levels' : 'Level ${player.nextStage(game, d)} · $stars ★';
    } else {
      final prev = Difficulty.values[d.index - 1];
      final need = PlayerStore.unlockStars[d.index] - player.trackStars(game, prev);
      sub = 'Earn $need more ★ in ${prev.label}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: open ? () => Navigator.pop(context, d) : null,
        semanticLabel: '${d.label}, $sub',
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: c.face,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(color: c.dark, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedText(
                      d.label,
                      size: 20,
                      color: open ? Colors.white : AppColors.inkSoft,
                      stroke: c.dark,
                      shadow: false,
                    ),
                    Text(
                      sub,
                      style: AppText.body(12, color: open ? Colors.white : AppColors.inkSoft, weight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(
                open ? Icons.chevron_right_rounded : Icons.lock_rounded,
                color: open ? Colors.white : AppColors.inkSoft,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home: today's daily puzzle up top, then every puzzle to choose from freely.
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
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
        children: [
          Row(
            children: [
              Pressable(
                onTap: () => context.push('/profile'),
                semanticLabel: 'Profile',
                child: Avatar(index: d.avatar, size: 46, ring: true),
              ),
              const SizedBox(width: 8),
              _LevelRibbon(level: d.playerLevel, progress: d.levelProgress),
              const Spacer(),
              CurrencyPill(art: ArtKind.coin, text: '${d.coins}', onPlus: () => context.go('/shop')),
              const SizedBox(width: 4),
              CurrencyPill(art: ArtKind.gem, text: '${d.totalGems}', onPlus: () => context.go('/shop'), minWidth: 64),
            ],
          ),
          const SizedBox(height: 10),
          // Looping animations get their own layer so they never repaint the page.
          RepaintBoundary(
            child: const Center(child: OutlinedText('Quintile', size: 50, stroke: Color(0xFF172873)))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: -2, end: 2, duration: 1800.ms, curve: Curves.easeInOut),
          ),
          const SizedBox(height: 30),
          const _DailyHero(),
          const SizedBox(height: 18),
          const Center(child: OutlinedText('Choose a puzzle', size: 24, stroke: Color(0xFF172873))),
          const SizedBox(height: 10),
          // Two per row; the fifth spans the full width so the grid never looks unfinished.
          for (var row = 0; row < 2; row++) ...[
            SizedBox(
              height: 170,
              child: Row(
                children: [
                  Expanded(child: _GameTile(game: GameType.values[row * 2])),
                  const SizedBox(width: 12),
                  Expanded(child: _GameTile(game: GameType.values[row * 2 + 1])),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(height: 150, child: _GameTile(game: GameType.values.last)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RewardButton(
                  art: ArtKind.chest,
                  label: p.canClaimLogin ? 'Daily gift!' : 'Daily gift',
                  ready: p.canClaimLogin,
                  onTap: () => showLoginCalendar(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RewardButton(
                  art: ArtKind.star,
                  label: p.canFreeSpin ? 'Free spin!' : 'Lucky spin',
                  ready: p.canFreeSpin,
                  onTap: () => context.push('/spin'),
                ),
              ),
            ],
          ),
        ].animate(interval: 50.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _LevelRibbon extends StatelessWidget {
  const _LevelRibbon({required this.level, required this.progress});
  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xCC172873),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: Candy.gold.face, borderRadius: BorderRadius.circular(13)),
            child: OutlinedText('Lv $level', size: 13, stroke: Candy.gold.dark, shadow: false),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: const Color(0xFF39D2FF),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}

/// Today's one daily puzzle: big, clear, with the streak and the reset countdown.
class _DailyHero extends StatelessWidget {
  const _DailyHero();

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final game = dailyFeatured();
    final done = p.dailyCompleted(game);
    final now = DateTime.now().toUtc();
    final reset = DateTime.utc(now.year, now.month, now.day + 1).difference(now);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CandyPanel(
          rim: game.candy,
          padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
          child: Row(
            children: [
              RepaintBoundary(
                child: GameBadge(game: game, size: 86)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .rotate(begin: -0.02, end: 0.02, duration: 1400.ms, curve: Curves.easeInOut),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: AppText.display(24)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF7A1A), size: 20),
                        const SizedBox(width: 2),
                        Text('${p.data.streak}-day streak', style: AppText.body(14, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (done)
                      Text(
                        'Solved! Next puzzle in ${reset.inHours}h ${reset.inMinutes % 60}m',
                        style: AppText.body(14, color: AppColors.success, weight: FontWeight.w700),
                      )
                    else
                      CandyButton(
                        label: 'Play',
                        candy: Candy.green,
                        height: 52,
                        width: 150,
                        pulse: true,
                        icon: Icons.play_arrow_rounded,
                        onTap: () => context.push('/play/daily/${game.name}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: -20,
          child: Center(child: RibbonBanner("Today's Puzzle", candy: game.candy, fontSize: 18, width: 230)),
        ),
      ],
    );
  }
}

/// A glossy tile for one puzzle; tap to choose a difficulty and play.
class _GameTile extends StatelessWidget {
  const _GameTile({required this.game});
  final GameType game;

  @override
  Widget build(BuildContext context) {
    final c = game.candy;
    final won = context.player.data.stats[game.wire]?.won ?? 0;
    return Pressable(
      onTap: () => showPlayPicker(context, game),
      scale: 0.95,
      semanticLabel: 'Play ${game.title}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.light, c.base]),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(color: c.dark, offset: const Offset(0, 6)),
            BoxShadow(color: c.dark.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 10)),
          ],
        ),
        child: Stack(
          children: [
            // Gloss.
            Positioned(
              left: 14,
              right: 14,
              top: 6,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white.withValues(alpha: 0.6), Colors.white.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GameBadge(game: game, size: 70),
                  const SizedBox(height: 8),
                  OutlinedText(game.title, size: 19, stroke: c.dark, maxLines: 1),
                  if (won > 0)
                    Text(
                      '$won won',
                      style: AppText.body(12, color: Colors.white, weight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardButton extends StatelessWidget {
  const _RewardButton({required this.art, required this.label, required this.onTap, this.ready = false});
  final ArtKind art;
  final String label;
  final VoidCallback onTap;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final tile = Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            GameArt(art, size: 36),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: AppText.display(17))),
            if (ready)
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
    return ready
        ? RepaintBoundary(
            child: tile
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.03, duration: 800.ms, curve: Curves.easeInOut),
          )
        : tile;
  }
}
