import 'dart:math' as math;

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
import '../../state/levels.dart';
import '../profile/invite.dart';
import '../rewards/rewards.dart';
import '../shop/shop_sheets.dart';

export '../../core/ui/game_cover.dart' show GameBadge;

/// Issue number of today's puzzle set (No. 1 = launch day).
int issueNumber(DateTime now) => now.toUtc().difference(DateTime.utc(2026, 1, 1)).inDays + 1;

/// Royal-Match-style hub: the world scene, currency bar, title, today's challenge, floating
/// reward buttons and one big pulsing button to play the next level.
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
    final level = d.currentLevel;
    final spec = Campaign.level(level);
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Column(
            children: [
              TopHud(
                onAvatar: () => context.push('/profile'),
                onHearts: () => showOutOfLives(context, browsing: true),
                onCoins: () => context.go('/shop'),
                onGems: () => context.go('/shop'),
              ),
              const SizedBox(height: 4),
              _LevelRibbon(level: d.playerLevel, progress: d.levelProgress),
              const SizedBox(height: 6),
              const OutlinedText('Quintile', size: 54, stroke: Color(0xFF172873))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: -3, end: 3, duration: 1800.ms, curve: Curves.easeInOut),
              const SizedBox(height: 10),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 70), child: _DailyChallenge()),
              const Spacer(),
              OutlinedText(Campaign.worldOf(level).name, size: 20, stroke: const Color(0xFF16810C)),
              const SizedBox(height: 6),
              CandyButton(
                label: 'Level $level',
                candy: Candy.green,
                height: 78,
                width: 250,
                fontSize: 32,
                pulse: true,
                leading: GameBadge(game: spec.game, size: 42),
                onTap: () async {
                  if (!context.services.player.canPlayLevel) {
                    await showOutOfLives(context);
                    return;
                  }
                  if (context.mounted) context.push('/play/level/$level');
                },
              ).animate().scale(begin: const Offset(0.6, 0.6), duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 108),
            ],
          ),
          // Floating reward buttons, like the side events in Royal Match.
          Positioned(
            left: 10,
            top: 150,
            child: Column(
              children: [
                _SideButton(
                  art: ArtKind.chest,
                  label: 'Gift',
                  badge: p.canClaimLogin,
                  phase: 0,
                  onTap: () => showLoginCalendar(context),
                ),
                _SideButton(
                  art: ArtKind.star,
                  label: 'Spin',
                  badge: p.canFreeSpin,
                  phase: 0.3,
                  onTap: () => context.push('/spin'),
                ),
                _SideButton(art: ArtKind.gem, label: 'Invite', phase: 0.6, onTap: () => _invite(context)),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 150,
            child: Column(
              children: [
                _SideButton(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFFF7A1A),
                  label: '${d.streak} days',
                  phase: 0.15,
                  onTap: () => context.go('/daily'),
                ),
                _SideButton(art: ArtKind.crown, label: 'Ranks', phase: 0.45, onTap: () => context.go('/leaders')),
                _SideButton(art: ArtKind.bolt, label: 'Practice', phase: 0.75, onTap: () => _practice(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _invite(BuildContext context) {
    showCandyDialog<void>(context, title: 'Invite friends', ribbon: Candy.pink, builder: (_) => const InviteCard());
  }

  void _practice(BuildContext context) {
    showCandyDialog<void>(
      context,
      title: 'Practice',
      ribbon: Candy.blue,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No lives needed — just play!', style: AppText.body(15, color: AppColors.inkSoft)),
          const SizedBox(height: 12),
          for (final g in GameType.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Pressable(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/play/quick/${g.name}');
                },
                semanticLabel: 'Practice ${g.title}',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: g.candy.light.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: g.candy.base, width: 2),
                  ),
                  child: Row(
                    children: [
                      GameBadge(game: g, size: 46),
                      const SizedBox(width: 12),
                      Expanded(child: Text(g.title, style: AppText.display(20))),
                      Icon(Icons.play_circle_fill_rounded, color: g.candy.base, size: 34),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Lv 3" ribbon with an XP bar.
class _LevelRibbon extends StatelessWidget {
  const _LevelRibbon({required this.level, required this.progress});
  final int level;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xCC172873),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: Candy.gold.face, borderRadius: BorderRadius.circular(14)),
            child: OutlinedText('Lv $level', size: 14, stroke: Candy.gold.dark, shadow: false),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                color: const Color(0xFF39D2FF),
                backgroundColor: Colors.white24,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

/// Today's five puzzles as glossy bubbles on a parchment panel, with the bonus chest.
class _DailyChallenge extends StatelessWidget {
  const _DailyChallenge();

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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CandyPanel(
            rim: Candy.pink,
            padding: const EdgeInsets.fromLTRB(12, 26, 12, 12),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in GameType.values)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GameBadge(game: g, size: 44),
                          if (p.dailyCompleted(g))
                            const Positioned(
                              right: -5,
                              bottom: -5,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: Stack(
                          children: [
                            Container(height: 18, color: const Color(0xFFF0DDB8)),
                            FractionallySizedBox(
                              widthFactor: done / 5,
                              child: Container(height: 18, decoration: BoxDecoration(gradient: Candy.gold.face)),
                            ),
                            Positioned.fill(
                              child: Center(
                                child: OutlinedText('$done / 5', size: 13, stroke: Candy.gold.dark, shadow: false),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const GameArt(
                      ArtKind.chest,
                      size: 32,
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(begin: -0.03, end: 0.03, duration: 700.ms),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'New puzzles in ${reset.inHours}h ${reset.inMinutes % 60}m',
                  style: AppText.body(12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            top: -18,
            child: Center(child: RibbonBanner('Daily Challenge', candy: Candy.pink, fontSize: 18, width: 220)),
          ),
        ],
      ),
    );
  }
}

/// Round glossy side button that gently bobs; [badge] shows a red "ready" dot.
class _SideButton extends StatelessWidget {
  const _SideButton({
    this.art,
    this.icon,
    this.iconColor,
    required this.label,
    required this.onTap,
    this.badge = false,
    this.phase = 0,
  });
  final ArtKind? art;
  final IconData? icon;
  final Color? iconColor;
  final String label;
  final VoidCallback onTap;
  final bool badge;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final bob = 1500 + math.Random(label.hashCode).nextInt(500);
    return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Pressable(
            onTap: onTap,
            semanticLabel: label,
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          center: Alignment(-0.3, -0.5),
                          colors: [Color(0xFFFFFFFF), Color(0xFFDDEBFF), Color(0xFF9DC2F5)],
                        ),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF3E64B8), offset: Offset(0, 4)),
                          BoxShadow(color: Color(0x55172873), blurRadius: 10, offset: Offset(0, 6)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: art != null
                          ? GameArt(art!, size: 36)
                          : Icon(
                              icon,
                              color: iconColor,
                              size: 34,
                              shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2))],
                            ),
                    ),
                    if (badge)
                      Positioned(
                        right: -2,
                        top: -2,
                        child:
                            Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                  ),
                                )
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.1, 1.1), duration: 600.ms),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                OutlinedText(label, size: 13, stroke: const Color(0xFF172873), shadow: false),
              ],
            ),
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true), delay: (phase * 1000).round().ms)
        .moveY(begin: -2.5, end: 2.5, duration: bob.ms, curve: Curves.easeInOut);
  }
}
