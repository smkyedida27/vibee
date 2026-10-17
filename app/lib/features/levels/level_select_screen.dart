import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_cover.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/player.dart';

/// All levels of one puzzle at one difficulty: stars per level, the current level glowing,
/// later levels locked until the one before is beaten.
class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.game, required this.difficulty});
  final GameType game;
  final Difficulty difficulty;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final _scroll = ScrollController();
  static const _cols = 5;
  static const _rowHeight = 92.0;

  @override
  void initState() {
    super.initState();
    // Open scrolled to the current level.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final next = context.services.player.nextStage(widget.game, widget.difficulty);
      final row = (next - 1) ~/ _cols;
      // Keep two rows of context above the current level.
      _scroll.jumpTo(((row - 2) * _rowHeight).clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _play(int n) => context.push('/play/stage/${widget.game.name}/${widget.difficulty.name}/$n');

  @override
  Widget build(BuildContext context) {
    final p = context.player;
    final g = widget.game, d = widget.difficulty;
    final next = p.nextStage(g, d);
    final stars = p.trackStars(g, d);
    const total = PlayerStore.stagesPerTrack;
    return Scaffold(
      body: CandyBackground(
        density: 0,
        gradient: AppColors.nightBg,
        child: SafeArea(
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
                      onTap: () => context.pop(),
                    ),
                    const SizedBox(width: 10),
                    GameBadge(game: g, size: 46),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedText(
                            g.title,
                            size: 24,
                            stroke: const Color(0xFF172873),
                            textAlign: TextAlign.left,
                            maxLines: 1,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                            decoration: BoxDecoration(gradient: d.candy.face, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              d.label,
                              style: AppText.body(12, color: Colors.white, weight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xCC172873),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white54, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                          const SizedBox(width: 2),
                          Text('$stars / ${total * 3}', style: AppText.display(15, color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: CandyButton(
                  label: p.stageStars(g, d, next) > 0 ? 'Replay level $next' : 'Play level $next',
                  icon: Icons.play_arrow_rounded,
                  candy: Candy.green,
                  height: 62,
                  pulse: true,
                  onTap: () => _play(next),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 30),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _cols,
                    mainAxisExtent: _rowHeight,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: total,
                  itemBuilder: (_, i) {
                    final n = i + 1;
                    return _LevelBubble(
                      n: n,
                      candy: g.candy,
                      stars: p.stageStars(g, d, n),
                      current: n == next,
                      locked: n > next,
                      onTap: () => _play(n),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelBubble extends StatelessWidget {
  const _LevelBubble({
    required this.n,
    required this.candy,
    required this.stars,
    required this.current,
    required this.locked,
    required this.onTap,
  });
  final int n;
  final Candy candy;
  final int stars;
  final bool current;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = locked ? Candy.grey : (current ? Candy.green : candy);
    final bubble = Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.3, -0.5), colors: [c.light, c.base, c.dark]),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: c.dark, offset: const Offset(0, 4)),
          if (current) BoxShadow(color: Candy.green.base.withValues(alpha: 0.7), blurRadius: 16),
        ],
      ),
      alignment: Alignment.center,
      child: locked
          ? const Icon(Icons.lock_rounded, color: Colors.white, size: 24)
          : OutlinedText('$n', size: n >= 100 ? 18 : 22, stroke: c.dark, shadow: false),
    );
    return Pressable(
      onTap: locked ? null : onTap,
      semanticLabel: locked ? 'Level $n, locked' : 'Level $n, $stars stars',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          current
              ? RepaintBoundary(
                  child: bubble
                      .animate(onPlay: (ctl) => ctl.repeat(reverse: true))
                      .scaleXY(begin: 0.95, end: 1.06, duration: 700.ms, curve: Curves.easeInOut),
                )
              : bubble,
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Icon(
                  Icons.star_rounded,
                  size: 15,
                  color: i < stars ? AppColors.gold : Colors.white.withValues(alpha: locked ? 0.15 : 0.35),
                  shadows: i < stars ? const [Shadow(color: Color(0xFFC77800), offset: Offset(0, 1))] : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
