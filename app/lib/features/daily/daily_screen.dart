import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
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
      child: Column(children: [
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
                const Center(child: RibbonBanner("Today's Challenge", candy: Candy.purple, fontSize: 26, width: 340)),
                const SizedBox(height: 6),
                Center(child: Text(_prettyDate(), style: AppText.body(15, color: Colors.white70))),
                const SizedBox(height: 14),
                _StreakCard(streak: p.data.streak, best: p.data.bestStreak),
                const SizedBox(height: 14),
                FutureBuilder<DailySet>(
                  future: _set,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: Colors.white)),
                      );
                    }
                    final set = snap.data!;
                    return Column(children: [
                      if (set.offline)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassPanel(
                            child: Row(children: [
                              const Icon(Icons.cloud_off_rounded, color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('Offline mode — your streak still counts. Scores sync to the leaderboard when online.',
                                    style: AppText.body(13, color: Colors.white)),
                              ),
                            ]),
                          ),
                        ),
                      for (final g in GameType.values)
                        if (set.puzzles[g] != null) _DailyRow(game: g, puzzle: set.puzzles[g]!, done: p.dailyCompleted(g)),
                    ]);
                  },
                ),
                const SizedBox(height: 6),
                CandyPanel(
                  rim: Candy.gold,
                  child: Row(children: [
                    const GameArt(ArtKind.chest, size: 56),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Complete all 5', style: AppText.display(20, color: AppColors.ink)),
                        Text('Earn a +300 coin bonus chest', style: AppText.body(13, color: AppColors.inkSoft)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: done / 5,
                            minHeight: 12,
                            backgroundColor: const Color(0xFFEDE4FF),
                            color: AppColors.success,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Text('$done/5', style: AppText.display(22, color: AppColors.royal)),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  String _prettyDate() {
    final d = DateTime.now().toUtc();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year} • resets at 00:00 UTC';
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.best});
  final int streak;
  final int best;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFFFF8A3D), Color(0xFFFF3D7F)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2.5),
        boxShadow: const [BoxShadow(color: Color(0xFFB0124E), offset: Offset(0, 6))],
      ),
      child: Row(children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFFE066), size: 60, shadows: [
            Shadow(color: Color(0xFFB0124E), offset: Offset(0, 3)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedText('$streak day streak', size: 26, textAlign: TextAlign.left, stroke: const Color(0xFF9E0A45)),
            Text(streak == 0 ? 'Solve any daily puzzle to start one!' : 'Best: $best days • keep it alive!',
                style: AppText.body(14, color: Colors.white)),
          ]),
        ),
      ]),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(10),
        child: Row(children: [
          GameBadge(game: game, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game.title, style: AppText.display(19)),
              Text('${puzzle.difficulty.label} • ${game.tagline}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.body(12, color: Colors.white70)),
            ]),
          ),
          const SizedBox(width: 8),
          done
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    Text('Done', style: AppText.display(15)),
                  ]),
                )
              : CandyButton(
                  label: 'Play',
                  candy: game.candy,
                  height: 48,
                  width: 92,
                  onTap: () => context.push('/play/daily/${game.name}'),
                ),
        ]),
      ),
    );
  }
}
