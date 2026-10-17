import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_cover.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/panels.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/player.dart';

const _flame = Color(0xFFFF7A1A);

/// The one daily puzzle everyone plays today, plus the streak it keeps alive.
class DailyScreen extends StatelessWidget {
  const DailyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final d = p.data;
    final game = dailyFeatured();
    final done = p.dailyCompleted(game);
    final now = DateTime.now().toUtc();
    final reset = DateTime.utc(now.year, now.month, now.day + 1).difference(now);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Center(child: OutlinedText('Daily Puzzle', size: 40, stroke: Color(0xFF172873))),
          Center(
            child: OutlinedText(
              done ? 'Next puzzle in ${reset.inHours}h ${reset.inMinutes % 60}m' : 'Same puzzle for everyone today',
              size: 16,
              stroke: const Color(0xFF172873),
              shadow: false,
            ),
          ),
          const SizedBox(height: 62),
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              CandyPanel(
                rim: game.candy,
                padding: const EdgeInsets.fromLTRB(18, 64, 18, 20),
                child: Column(
                  children: [
                    Text(game.title, style: AppText.display(30)),
                    const SizedBox(height: 4),
                    Text(
                      game.tagline,
                      textAlign: TextAlign.center,
                      style: AppText.body(15, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 18),
                    if (done) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F8DE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success),
                            const SizedBox(width: 8),
                            Text('Solved today!', style: AppText.display(18, color: AppColors.success)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      CandyButton(
                        label: "Today's leaderboard",
                        icon: Icons.emoji_events_rounded,
                        candy: Candy.ink,
                        height: 56,
                        onTap: () => context.go('/leaders'),
                      ),
                    ] else
                      CandyButton(
                        label: 'Play now',
                        icon: Icons.play_arrow_rounded,
                        candy: Candy.green,
                        height: 64,
                        pulse: true,
                        onTap: () => context.push('/play/daily/${game.name}'),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: -40,
                child: RepaintBoundary(
                  child: GameBadge(game: game, size: 96)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: -3, end: 3, duration: 1500.ms, curve: Curves.easeInOut),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded, color: _flame, size: 40),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.streak == 0 ? 'Start your streak' : '${d.streak}-day streak',
                            style: AppText.display(22),
                          ),
                          Text(
                            'Solve the daily puzzle every day to grow it',
                            style: AppText.body(13, color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text('BEST', style: AppText.label(10)),
                        Text('${d.bestStreak}', style: AppText.display(22)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _Week(data: d),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({required this.data});
  final PlayerData data;

  @override
  Widget build(BuildContext context) {
    final playedToday = data.lastStreakDate == utcDate();
    final now = DateTime.now();
    final covered = <int>{};
    if (data.streak > 0 && data.lastStreakDate != null) {
      final endOffset = playedToday ? 0 : 1;
      for (var i = 0; i < data.streak && i + endOffset < 7; i++) {
        covered.add(i + endOffset);
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var back = 6; back >= 0; back--)
          Column(
            children: [
              Text(
                'MTWTFSS'[now.subtract(Duration(days: back)).weekday - 1],
                style: AppText.body(12, color: back == 0 ? AppColors.ink : AppColors.inkFaint, weight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: covered.contains(back) ? Candy.orange.face : null,
                  color: covered.contains(back) ? null : const Color(0xFFF0E1C2),
                  border: back == 0 && !covered.contains(back) ? Border.all(color: _flame, width: 2.5) : null,
                ),
                child: covered.contains(back) ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
              ),
            ],
          ),
      ],
    );
  }
}
