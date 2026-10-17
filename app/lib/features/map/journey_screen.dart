import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/levels.dart';
import '../shop/shop_sheets.dart';

/// The saga map: a calm winding path through themed worlds, bottom to top.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  static const spacing = 104.0;
  static const headerH = 120.0;
  static const segH = Campaign.levelsPerWorld * spacing + headerH;
  ScrollController? _scroll;

  int get _worldCount => Campaign.totalLevels ~/ Campaign.levelsPerWorld;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scroll == null) {
      final current = context.player.data.currentLevel;
      final w = Campaign.worldIndex(current);
      final k = (current - 1) % Campaign.levelsPerWorld;
      final viewport = MediaQuery.sizeOf(context).height;
      _scroll = ScrollController(initialScrollOffset: math.max(0, w * segH + k * spacing - viewport * 0.35));
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  static double nodeX(int level) => 0.5 + 0.3 * math.sin(level * 0.72);

  Future<void> _openLevel(int n) async {
    final s = context.services;
    final spec = Campaign.level(n);
    final stars = s.player.data.levelStars[n] ?? 0;
    final go = await showCandyDialog<bool>(
      context,
      title: 'Level $n',
      ribbon: spec.boss ? Candy.red : spec.game.candy,
      builder: (ctx) => _LevelPreview(spec: spec, stars: stars),
    );
    if (go != true || !mounted) return;
    if (!s.player.canPlayLevel) {
      await showOutOfLives(context);
      return;
    }
    context.push('/play/level/$n');
  }

  @override
  Widget build(BuildContext context) {
    final d = context.player.data;
    final current = d.currentLevel;
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          itemCount: _worldCount,
          itemExtent: segH,
          itemBuilder: (context, w) =>
              _WorldSegment(worldIndex: w, current: current, stars: d.levelStars, onTap: _openLevel, avatar: d.avatar),
        ),
        // HUD over the map.
        SafeArea(
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.bg, AppColors.bg.withValues(alpha: 0)],
                    stops: const [0.7, 1],
                  ),
                ),
                child: TopHud(
                  onAvatar: () => context.push('/profile'),
                  onHearts: () => showOutOfLives(context, browsing: true),
                  onCoins: () => context.go('/shop'),
                  onGems: () => context.go('/shop'),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: CandyIconButton(
            icon: Icons.my_location_rounded,
            candy: Candy.ink,
            size: 52,
            semanticLabel: 'Jump to current level',
            onTap: () {
              final w = Campaign.worldIndex(current);
              final k = (current - 1) % Campaign.levelsPerWorld;
              _scroll?.animateTo(
                math.max(0, w * segH + k * spacing - MediaQuery.sizeOf(context).height * 0.35),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOutCubic,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorldSegment extends StatelessWidget {
  const _WorldSegment({
    required this.worldIndex,
    required this.current,
    required this.stars,
    required this.onTap,
    required this.avatar,
  });
  final int worldIndex;
  final int current;
  final Map<int, int> stars;
  final ValueChanged<int> onTap;
  final int avatar;

  @override
  Widget build(BuildContext context) {
    final world = Campaign.worlds[worldIndex % Campaign.worlds.length];
    final first = worldIndex * Campaign.levelsPerWorld + 1;
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        Offset node(int level) {
          final k = level - first;
          // Neighbouring worlds' nodes (k < 0 or k >= levelsPerWorld) sit across the header gap.
          final gap = k < 0
              ? _JourneyScreenState.headerH
              : (k >= Campaign.levelsPerWorld ? -_JourneyScreenState.headerH : 0.0);
          return Offset(
            _JourneyScreenState.nodeX(level) * w,
            _JourneyScreenState.segH - (k + 0.6) * _JourneyScreenState.spacing + gap,
          );
        }

        final worldStars = [for (var l = first; l < first + Campaign.levelsPerWorld; l++) stars[l] ?? 0]
            .fold(0, (a, b) => a + b);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _WorldPainter(
                    world: world,
                    seed: worldIndex,
                    first: first,
                    current: current,
                    nodes: [for (var l = first - 1; l <= first + Campaign.levelsPerWorld; l++) node(l)],
                  ),
                ),
              ),
            ),
            // World title card at the top of the segment.
            Positioned(
              top: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: world.accent, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('WORLD ${worldIndex + 1}', style: AppText.label(11)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(world.name, style: AppText.display(20)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$worldStars / ${Campaign.levelsPerWorld * 3}',
                            style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (var l = first; l < first + Campaign.levelsPerWorld; l++) _positioned(node(l), l),
          ],
        );
      },
    );
  }

  Widget _positioned(Offset p, int level) {
    final spec = Campaign.level(level);
    final size = spec.boss ? 64.0 : 54.0;
    return Positioned(
      left: p.dx - size / 2 - 20,
      top: p.dy - size / 2 - 30,
      width: size + 40,
      height: size + 56,
      child: _LevelNode(
        level: level,
        spec: spec,
        size: size,
        stars: stars[level] ?? 0,
        state: level < current ? _NodeState.done : (level == current ? _NodeState.current : _NodeState.locked),
        onTap: () => onTap(level),
        avatar: avatar,
      ),
    );
  }
}

enum _NodeState { done, current, locked }

class _LevelNode extends StatefulWidget {
  const _LevelNode({
    required this.level,
    required this.spec,
    required this.size,
    required this.stars,
    required this.state,
    required this.onTap,
    required this.avatar,
  });
  final int level;
  final LevelSpec spec;
  final double size;
  final int stars;
  final _NodeState state;
  final VoidCallback onTap;
  final int avatar;

  @override
  State<_LevelNode> createState() => _LevelNodeState();
}

class _LevelNodeState extends State<_LevelNode> with TickerProviderStateMixin {
  AnimationController? _bob;

  @override
  void initState() {
    super.initState();
    _syncBob();
  }

  // Nodes are reused when a level is cleared, so the "current" bob follows the state.
  @override
  void didUpdateWidget(covariant _LevelNode old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) _syncBob();
  }

  void _syncBob() {
    final current = widget.state == _NodeState.current;
    if (current && _bob == null) {
      _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    } else if (!current && _bob != null) {
      _bob!.dispose();
      _bob = null;
    }
  }

  @override
  void dispose() {
    _bob?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.state == _NodeState.locked;
    final isCurrent = widget.state == _NodeState.current;
    final accent = widget.spec.boss ? Candy.red : widget.spec.game.candy;
    final fill = locked ? AppColors.surface : (isCurrent ? AppColors.primary : accent.base);
    final fg = locked ? AppColors.inkFaint : Colors.white;
    final s = widget.size;
    final node = Pressable(
      onTap: locked ? null : widget.onTap,
      sound: Sfx.pop,
      semanticLabel: 'Level ${widget.level}, ${widget.spec.game.title}, ${locked ? 'locked' : '${widget.stars} stars'}',
      child: Container(
        width: s,
        height: s,
        padding: EdgeInsets.all(isCurrent ? 4 : 0),
        decoration: isCurrent
            ? BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 3),
                boxShadow: AppColors.cardShadow,
              )
            : null,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: locked ? Border.all(color: AppColors.border, width: 1.5) : null,
            boxShadow: isCurrent ? null : AppColors.cardShadow,
          ),
          child: locked
              ? Icon(Icons.lock_rounded, color: fg, size: s * 0.36)
              : Text(
                  '${widget.level}',
                  style: AppText.display(s * (widget.level >= 100 ? 0.3 : 0.36), color: fg, height: 1),
                ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: widget.state == _NodeState.done
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: EdgeInsets.only(bottom: i == 1 ? 4 : 0),
                        child: Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: i < widget.stars ? AppColors.gold : AppColors.border,
                        ),
                      ),
                  ],
                )
              : (widget.spec.boss && !locked
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(999)),
                        child: Text('HARD', style: AppText.label(10, color: Colors.white)),
                      )
                    : null),
        ),
        if (_bob != null)
          AnimatedBuilder(
            animation: _bob!,
            builder: (_, child) =>
                Transform.scale(scale: 1 + 0.03 * Curves.easeInOut.transform(_bob!.value), child: child),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                node,
                Positioned(
                  top: -46,
                  child: AnimatedBuilder(
                    animation: _bob!,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, -3 * Curves.easeInOut.transform(_bob!.value)),
                      child: child,
                    ),
                    child: Avatar(index: widget.avatar, size: 36, ring: true),
                  ),
                ),
              ],
            ),
          )
        else
          node,
      ],
    );
  }
}

class _WorldPainter extends CustomPainter {
  _WorldPainter({
    required this.world,
    required this.seed,
    required this.first,
    required this.current,
    required this.nodes,
  });
  final World world;
  final int seed;
  final int first;
  final int current;
  final List<Offset> nodes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.bg);

    // The path: one soft, continuous line; the cleared stretch is tinted with the brand colour.
    final road = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (var i = 1; i < nodes.length; i++) {
      final a = nodes[i - 1], b = nodes[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      road.quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy);
      road.quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
    }
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(road, line..color = AppColors.border);

    // nodes[0] is level first-1; index i is level first-1+i. Tint up to the current level.
    final cleared = (current - (first - 1)).clamp(0, nodes.length - 1);
    if (cleared > 0) {
      final metrics = road.computeMetrics().toList();
      if (metrics.isNotEmpty) {
        final m = metrics.first;
        final frac = cleared / (nodes.length - 1);
        canvas.drawPath(m.extractPath(0, m.length * frac), line..color = AppColors.primary.withValues(alpha: 0.22));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) => old.current != current || old.nodes.first != nodes.first;
}

class _LevelPreview extends StatelessWidget {
  const _LevelPreview({required this.spec, required this.stars});
  final LevelSpec spec;
  final int stars;

  @override
  Widget build(BuildContext context) {
    final g = spec.game;
    final goals = switch (g) {
      GameType.connect => '★★★ no mistakes  •  ★★ up to 2',
      GameType.queens => '★★★ solve without hints',
      GameType.sudoku => '★★★ no mistakes & no hints',
      GameType.ladder => '★★★ match par  •  ★★ par + 2',
      GameType.merge => '★★★ reach ${Campaign.mergeTarget(spec.difficulty)}',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: EdgeInsets.only(bottom: i == 1 ? 10 : 0, left: 2, right: 2),
                child: Icon(
                  Icons.star_rounded,
                  size: i == 1 ? 52 : 40,
                  color: i < stars ? AppColors.gold : AppColors.border,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: g.candy.base, borderRadius: BorderRadius.circular(14)),
                child: Icon(g.icon, color: g.candy.on, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title, style: AppText.display(18)),
                    Text(g.tagline, style: AppText.body(13, color: AppColors.inkSoft)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: spec.difficulty.candy.base,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            spec.difficulty.label,
                            style: AppText.body(11, color: spec.difficulty.candy.on, weight: FontWeight.w700),
                          ),
                        ),
                        if (spec.boss) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'HARD LEVEL',
                              style: AppText.body(11, color: Colors.white, weight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          goals,
          textAlign: TextAlign.center,
          style: AppText.body(14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        CandyButton(
          label: 'Play',
          candy: Candy.green,
          height: 56,
          pulse: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 2),
              Text('-1', style: AppText.display(15, color: Colors.white)),
            ],
          ),
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
