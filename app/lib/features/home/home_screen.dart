import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/panels.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/levels.dart';
import '../rewards/rewards.dart';
import '../shop/shop_sheets.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showLoginCalendar(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final d = p.data;
    final level = d.currentLevel;
    final spec = Campaign.level(level);
    final greeting = switch (DateTime.now().hour) {
      < 12 => 'Good morning',
      < 18 => 'Good afternoon',
      _ => 'Good evening',
    };
    return SafeArea(
      child: Column(
        children: [
          TopHud(
            onAvatar: () => context.push('/profile'),
            onHearts: () => showOutOfLives(context, browsing: true),
            onCoins: () => context.go('/shop'),
            onGems: () => context.go('/shop'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
              children: [
                Text('$greeting, ${d.displayName}!', style: AppText.body(16, color: Colors.white70)),
                const SizedBox(height: 2),
                const OutlinedText('Ready to play?', size: 32, textAlign: TextAlign.left),
                const SizedBox(height: 14),
                const _DailyHero(),
                const SizedBox(height: 14),
                _ContinueCard(level: level, spec: spec),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _RewardTile(
                        art: ArtKind.chest,
                        title: 'Daily Gift',
                        subtitle: p.canClaimLogin ? 'Ready to open!' : 'Come back tomorrow',
                        glow: p.canClaimLogin,
                        onTap: () => showLoginCalendar(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _RewardTile(
                        art: ArtKind.star,
                        title: 'Lucky Spin',
                        subtitle: p.canFreeSpin ? 'Free spin ready' : 'Spin with an ad',
                        glow: p.canFreeSpin,
                        onTap: () => context.push('/spin'),
                      ),
                    ),
                  ],
                ),
                SectionTitle(
                  'Quick Play',
                  trailing: Text('Practice • no lives', style: AppText.body(13, color: Colors.white70)),
                ),
                for (final g in GameType.values) _GameRow(game: g),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyHero extends StatelessWidget {
  const _DailyHero();

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final done = GameType.values.where(p.dailyCompleted).length;
    final now = DateTime.now().toUtc();
    final reset = DateTime.utc(now.year, now.month, now.day + 1).difference(now);
    return Pressable(
      onTap: () => context.go('/daily'),
      scale: 0.97,
      semanticLabel: 'Daily challenge, $done of 5 done',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF6FB5), Color(0xFFFF3D7F), Color(0xFFFF8A3D)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 3),
          boxShadow: [
            const BoxShadow(color: Color(0xFFB0124E), offset: Offset(0, 7)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: OutlinedText(
                    'Daily Challenge',
                    size: 26,
                    textAlign: TextAlign.left,
                    stroke: Color(0xFF9E0A45),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFE066), size: 20),
                      const SizedBox(width: 2),
                      Text('${p.data.streak}', style: AppText.display(18)),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              'New puzzles in ${reset.inHours}h ${reset.inMinutes % 60}m',
              style: AppText.body(13, color: Colors.white.withValues(alpha: 0.9)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final g in GameType.values)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GameBadge(game: g, size: 50),
                      if (p.dailyCompleted(g))
                        const Positioned(
                          right: -4,
                          bottom: -4,
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Container(height: 18, color: Colors.black.withValues(alpha: 0.2)),
                        FractionallySizedBox(
                          widthFactor: done / 5,
                          child: Container(height: 18, decoration: BoxDecoration(gradient: Candy.gold.face)),
                        ),
                        Positioned.fill(
                          child: Center(child: Text('$done / 5', style: AppText.display(13))),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const GameArt(ArtKind.chest, size: 34),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.level, required this.spec});
  final int level;
  final LevelSpec spec;

  @override
  Widget build(BuildContext context) {
    final world = Campaign.worldOf(level);
    return CandyPanel(
      rim: Candy.blue,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          GameBadge(game: spec.game, size: 64),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  world.name.toUpperCase(),
                  style: AppText.body(11, color: AppColors.inkSoft, weight: FontWeight.w800),
                ),
                Text('Level $level', style: AppText.display(26, color: AppColors.ink)),
                Text(
                  '${spec.game.title} • ${spec.difficulty.label}',
                  style: AppText.body(13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          CandyButton(
            label: 'Play',
            candy: Candy.green,
            height: 58,
            width: 104,
            pulse: true,
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
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.art,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.glow = false,
  });
  final ArtKind art;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: glow ? AppColors.gold : Colors.white24, width: glow ? 2.5 : 1.5),
          boxShadow: glow ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.5), blurRadius: 16)] : null,
        ),
        child: Row(
          children: [
            GameArt(art, size: 42),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.display(17)),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(11, color: Colors.white70),
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

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game});
  final GameType game;

  @override
  Widget build(BuildContext context) {
    final stats = context.player.data.stats[game.wire];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: () => context.push('/play/quick/${game.name}'),
        scale: 0.97,
        semanticLabel: 'Play ${game.title}',
        child: GlassPanel(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              GameBadge(game: game, size: 54),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: AppText.display(19)),
                    Text(game.tagline, style: AppText.body(12, color: Colors.white70)),
                  ],
                ),
              ),
              if (stats != null && stats.won > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${stats.won} won',
                    style: AppText.body(12, color: Colors.white70, weight: FontWeight.w700),
                  ),
                ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: game.candy.face),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glossy rounded-square game icon.
class GameBadge extends StatelessWidget {
  const GameBadge({super.key, required this.game, this.size = 56});
  final GameType game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = game.candy;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: c.face,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: Colors.white, width: size * 0.05),
        boxShadow: [
          BoxShadow(color: c.dark, offset: Offset(0, size * 0.07)),
          BoxShadow(color: Colors.black26, blurRadius: size * 0.2),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.07,
            left: size * 0.14,
            right: size * 0.14,
            height: size * 0.3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.65), Colors.white.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          _GameGlyph(game: game, size: size * 0.56),
        ],
      ),
    );
  }
}

/// Distinctive per-game glyphs drawn from primitives.
class _GameGlyph extends StatelessWidget {
  const _GameGlyph({required this.game, required this.size});
  final GameType game;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = AppText.display(size * 0.62);
    switch (game) {
      case GameType.connect:
        return SizedBox.square(
          dimension: size,
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: size * 0.08,
            crossAxisSpacing: size * 0.08,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (final ch in ['A', 'B', 'C', 'D'])
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.08)),
                  alignment: Alignment.center,
                  child: Text(ch, style: AppText.display(size * 0.3, color: game.candy.dark)),
                ),
            ],
          ),
        );
      case GameType.queens:
        return GameArt(ArtKind.crown, size: size * 1.1);
      case GameType.sudoku:
        return Text(
          '9',
          style: style.copyWith(
            shadows: [Shadow(color: game.candy.dark, offset: const Offset(0, 2))],
          ),
        );
      case GameType.ladder:
        return Icon(
          Icons.stairs_rounded,
          color: Colors.white,
          size: size,
          shadows: [Shadow(color: game.candy.dark, offset: const Offset(0, 2))],
        );
      case GameType.merge:
        return Container(
          width: size * 0.9,
          height: size * 0.9,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.2)),
          child: Text('2K', style: AppText.display(size * 0.4, color: game.candy.dark)),
        );
    }
  }
}
