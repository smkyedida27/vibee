import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/panels.dart';
import '../../games/common/game_type.dart';
import '../../services/content_repo.dart';
import '../../services/services.dart';
import '../home/home_screen.dart';
import '../shop/shop_sheets.dart';

class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late Future<DailySet> _set;

  // Fetched once per visit (and on pull-to-refresh) — not on every player change.
  @override
  void initState() {
    super.initState();
    _set = context.services.content.daily();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final done = GameType.values.where(p.dailyCompleted).length;
    return SafeArea(
      child: Column(
        children: [
          TopHud(onAvatar: () => context.push('/profile'), onHearts: () => showOutOfLives(context, browsing: true)),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _set = context.services.content.daily());
                await _set;
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                children: [
                  Text(_prettyDate().toUpperCase(), style: AppText.label(11)),
                  const SizedBox(height: 4),
                  Text("Today's Challenge", style: AppText.display(30)),
                  const SizedBox(height: 16),
                  _StreakCard(streak: p.data.streak, best: p.data.bestStreak),
                  const SizedBox(height: 24),
                  Text('PUZZLES', style: AppText.label(11)),
                  const SizedBox(height: 12),
                  FutureBuilder<DailySet>(
                    future: _set,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(40),
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3)),
                        );
                      }
                      final set = snap.data!;
                      return Column(
                        children: [
                          if (set.offline)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: GlassPanel(
                                child: Row(
                                  children: [
                                    const Icon(Icons.cloud_off_rounded, color: AppColors.inkSoft),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Offline mode — your streak still counts, but offline scores aren\'t ranked. Go online to compete on the leaderboard.',
                                        style: AppText.body(13, color: AppColors.inkSoft),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          for (final g in GameType.values)
                            if (set.puzzles[g] != null)
                              _DailyRow(game: g, puzzle: set.puzzles[g]!, done: p.dailyCompleted(g)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  CandyPanel(
                    rim: Candy.gold,
                    accent: true,
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: Candy.gold.light, borderRadius: BorderRadius.circular(14)),
                          child: const GameArt(ArtKind.chest, size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Complete all 5', style: AppText.display(17)),
                              const SizedBox(height: 2),
                              Text('Earn a +300 coin bonus chest', style: AppText.body(13, color: AppColors.inkSoft)),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: done / 5,
                                  minHeight: 8,
                                  backgroundColor: AppColors.divider,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text('$done/5', style: AppText.display(22, color: AppColors.primary)),
                      ],
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

  String _prettyDate() {
    final d = DateTime.now().toUtc();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year} · Resets 00:00 UTC';
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.best});
  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.primary,
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFC94D), size: 34),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('STREAK', style: AppText.label(11, color: Colors.white.withValues(alpha: 0.72))),
                const SizedBox(height: 2),
                Text('$streak day${streak == 1 ? '' : 's'}', style: AppText.display(26, color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                  streak == 0 ? 'Solve any daily puzzle to start one' : 'Best: $best days · keep it alive',
                  style: AppText.body(13, color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.game, required this.puzzle, required this.done});
  final GameType game;
  final DailyPuzzle puzzle;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            GameBadge(game: game, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(game.title, style: AppText.display(16)),
                  const SizedBox(height: 2),
                  Text(
                    '${puzzle.difficulty.label} · ${game.tagline}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(13, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            done
                ? Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Candy.green.light, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 4),
                        Text('Done', style: AppText.display(14, color: AppColors.success)),
                      ],
                    ),
                  )
                : CandyButton(
                    label: 'Play',
                    candy: game.candy,
                    height: 44,
                    width: 88,
                    onTap: () => context.push('/play/daily/${game.name}'),
                  ),
          ],
        ),
      ),
    );
  }
}
