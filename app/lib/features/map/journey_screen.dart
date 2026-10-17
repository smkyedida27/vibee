import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/services.dart';
import '../../state/levels.dart';
import '../shop/shop_sheets.dart';

/// The saga map: a winding candy road through themed worlds, bottom to top.
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
                    colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
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
          right: 14,
          bottom: 16,
          child: CandyIconButton(
            icon: Icons.my_location_rounded,
            candy: Candy.pink,
            size: 54,
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
            // World title banner at the top of the segment.
            Positioned(
              top: 34,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'WORLD ${worldIndex + 1}',
                          style: AppText.body(12, color: Colors.white70, weight: FontWeight.w800),
                        ),
                        OutlinedText(world.name, size: 26, stroke: const Color(0xFF3B0E7A)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const GameArt(ArtKind.star, size: 16),
                            const SizedBox(width: 4),
                            Text('$worldStars / ${Campaign.levelsPerWorld * 3}', style: AppText.display(14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
    final size = spec.boss ? 74.0 : 60.0;
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
      _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
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
    final c = locked ? Candy.grey : (widget.spec.boss ? Candy.red : widget.spec.game.candy);
    final s = widget.size;
    final node = Pressable(
      onTap: locked ? null : widget.onTap,
      sound: Sfx.pop,
      semanticLabel: 'Level ${widget.level}, ${widget.spec.game.title}, ${locked ? 'locked' : '${widget.stars} stars'}',
      child: SizedBox(
        width: s,
        height: s + 6,
        child: Stack(
          children: [
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              height: s,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.dark,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 5)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: s,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.5),
                    radius: 1.0,
                    colors: [c.light, c.base, c.dark],
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: s * 0.1,
                      left: s * 0.22,
                      child: Container(
                        width: s * 0.3,
                        height: s * 0.16,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(s),
                        ),
                      ),
                    ),
                    if (locked)
                      Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.9), size: s * 0.42)
                    else
                      OutlinedText(
                        '${widget.level}',
                        size: s * (widget.level >= 100 ? 0.34 : 0.42),
                        stroke: c.dark,
                        shadow: false,
                      ),
                  ],
                ),
              ),
            ),
          ],
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
                        padding: EdgeInsets.only(bottom: i == 1 ? 6 : 0),
                        child: GameArt(i < widget.stars ? ArtKind.star : ArtKind.starEmpty, size: 20),
                      ),
                  ],
                )
              : (widget.spec.boss && !locked
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                        child: Text('HARD', style: AppText.display(12)),
                      )
                    : null),
        ),
        if (_bob != null)
          AnimatedBuilder(
            animation: _bob!,
            builder: (_, child) =>
                Transform.scale(scale: 1 + 0.07 * Curves.easeInOut.transform(_bob!.value), child: child),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                node,
                Positioned(
                  top: -50,
                  child: AnimatedBuilder(
                    animation: _bob!,
                    builder: (_, child) => Transform.translate(offset: Offset(0, -6 * _bob!.value), child: child),
                    child: Avatar(index: widget.avatar, size: 40, ring: true),
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
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [world.bottom, world.top, world.bottom],
          stops: const [0, 0.5, 1],
        ).createShader(rect),
    );
    final r = math.Random(seed * 7919 + 13);

    // Rolling hills bands.
    for (var band = 0; band < 6; band++) {
      final y = size.height * (band + 0.6) / 6;
      final hill = Path()..moveTo(0, y);
      for (var x = 0.0; x <= size.width; x += 20) {
        hill.lineTo(x, y + math.sin(x / 70 + band * 1.7 + seed) * 22);
      }
      hill
        ..lineTo(size.width, y + 160)
        ..lineTo(0, y + 160)
        ..close();
      canvas.drawPath(hill, Paint()..color = Colors.white.withValues(alpha: 0.07));
    }

    // Scattered decorations: lollipops, gumdrops, sparkles, clouds.
    for (var i = 0; i < 26; i++) {
      final p = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      // Keep decorations off the road.
      final tooClose = nodes.any((n) => (n - p).distance < 70);
      if (tooClose) continue;
      switch (r.nextInt(4)) {
        case 0:
          _lollipop(canvas, p, 16 + r.nextDouble() * 14, r.nextBool() ? world.accent : Colors.white);
        case 1:
          _gumdrop(canvas, p, 14 + r.nextDouble() * 12, HSVColor.fromAHSV(1, r.nextDouble() * 360, 0.55, 1).toColor());
        case 2:
          _cloud(canvas, p, 30 + r.nextDouble() * 30);
        default:
          _sparkle(canvas, p, 4 + r.nextDouble() * 6);
      }
    }

    // The road: dark under-stroke, cream body, candy-stripe dashes.
    final road = Path()..moveTo(nodes.first.dx, nodes.first.dy);
    for (var i = 1; i < nodes.length; i++) {
      final a = nodes[i - 1], b = nodes[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      road.quadraticBezierTo(a.dx, mid.dy, mid.dx, mid.dy);
      road.quadraticBezierTo(b.dx, mid.dy, b.dx, b.dy);
    }
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 30
        ..strokeCap = StrokeCap.round
        ..color = Colors.black.withValues(alpha: 0.18),
    );
    canvas.drawPath(
      road,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24
        ..strokeCap = StrokeCap.round
        ..color = world.path,
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = world.accent.withValues(alpha: 0.75);
    for (final metric in road.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 26) {
        canvas.drawPath(metric.extractPath(d, d + 10), dash);
      }
    }
  }

  void _lollipop(Canvas c, Offset p, double r, Color color) {
    c.drawLine(
      p,
      p + Offset(0, r * 2.4),
      Paint()
        ..color = Colors.white
        ..strokeWidth = r * 0.25
        ..strokeCap = StrokeCap.round,
    );
    c.drawCircle(p, r, Paint()..color = color);
    final swirl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.22
      ..color = Colors.white.withValues(alpha: 0.8);
    c.drawArc(Rect.fromCircle(center: p, radius: r * 0.65), 0, math.pi * 1.5, false, swirl);
    c.drawArc(Rect.fromCircle(center: p, radius: r * 0.3), math.pi, math.pi * 1.5, false, swirl);
  }

  void _gumdrop(Canvas c, Offset p, double r, Color color) {
    final path = Path()
      ..moveTo(p.dx - r, p.dy + r * 0.6)
      ..quadraticBezierTo(p.dx - r, p.dy - r * 1.1, p.dx, p.dy - r * 1.1)
      ..quadraticBezierTo(p.dx + r, p.dy - r * 1.1, p.dx + r, p.dy + r * 0.6)
      ..close();
    c.drawPath(path.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.15));
    c.drawPath(path, Paint()..color = color);
    c.drawOval(
      Rect.fromLTWH(p.dx - r * 0.5, p.dy - r * 0.8, r * 0.4, r * 0.3),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _cloud(Canvas c, Offset p, double w) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    c.drawCircle(p, w * 0.35, paint);
    c.drawCircle(p + Offset(w * 0.35, w * 0.06), w * 0.28, paint);
    c.drawCircle(p + Offset(-w * 0.35, w * 0.08), w * 0.25, paint);
  }

  void _sparkle(Canvas c, Offset p, double s) {
    final path = Path()
      ..moveTo(p.dx, p.dy - s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + s)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - s, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - s);
    c.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.75));
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
                padding: EdgeInsets.only(bottom: i == 1 ? 12 : 0, left: 2, right: 2),
                child: GameArt(i < stars ? ArtKind.star : ArtKind.starEmpty, size: i == 1 ? 54 : 42),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFF6F0FF), borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: g.candy.face,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: g.candy.dark, width: 2),
                  boxShadow: [BoxShadow(color: g.candy.dark, offset: const Offset(0, 4))],
                ),
                child: Icon(g.icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.title, style: AppText.display(22, color: AppColors.ink)),
                    Text(g.tagline, style: AppText.body(13, color: AppColors.inkSoft)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: spec.difficulty.candy.base,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            spec.difficulty.label,
                            style: AppText.body(11, color: Colors.white, weight: FontWeight.w800),
                          ),
                        ),
                        if (spec.boss) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(8)),
                            child: Text(
                              'HARD LEVEL',
                              style: AppText.body(11, color: Colors.white, weight: FontWeight.w800),
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
        const SizedBox(height: 10),
        Text(
          goals,
          textAlign: TextAlign.center,
          style: AppText.body(14, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 16),
        CandyButton(
          label: 'Play',
          candy: Candy.green,
          height: 66,
          pulse: true,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const GameArt(ArtKind.heart, size: 26),
              Text('-1', style: AppText.display(18)),
            ],
          ),
          onTap: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}
