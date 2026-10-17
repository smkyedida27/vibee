import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// The living world behind every screen: sky, a slowly turning sun, drifting clouds,
/// rolling hills with a castle, trees, flowers and twinkling sparkles.
///
/// Performance: the scenery (hills, castle, trees, flowers) never changes, so it is painted
/// once into its own cached layer; only the light sky layer (sun, clouds, sparkles) repaints
/// each frame. Freezes when the player prefers reduced motion.
///
/// [orbColors] is kept for compatibility. [density] 0 shows a calm sky without scenery
/// (used behind game boards).
class CandyBackground extends StatefulWidget {
  const CandyBackground({
    super.key,
    required this.child,
    this.gradient = AppColors.worldBg,
    this.orbColors = const [],
    this.density = 14,
  });

  final Widget child;
  final Gradient gradient;
  final List<Color> orbColors;
  final int density;

  @override
  State<CandyBackground> createState() => _CandyBackgroundState();
}

class _CandyBackgroundState extends State<CandyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: widget.gradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: CustomPaint(painter: _SkyPainter(_c))),
          if (widget.density > 0) const RepaintBoundary(child: CustomPaint(painter: _SceneryPainter())),
          // Content repaints on its own layer, never forcing the world to redraw.
          RepaintBoundary(child: widget.child),
        ],
      ),
    );
  }
}

/// Sun, clouds and sparkles: the only parts that move.
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.anim) : super(repaint: anim);
  final Animation<double> anim;

  static final _rand = math.Random(11);
  static final _clouds = List.generate(
    5,
    (i) => (
      _rand.nextDouble(),
      0.05 + _rand.nextDouble() * 0.35,
      0.6 + _rand.nextDouble() * 0.8,
      0.5 + _rand.nextDouble(),
    ),
  );
  static final _sparkles = List.generate(
    10,
    (i) => (_rand.nextDouble(), _rand.nextDouble() * 0.6, _rand.nextDouble() * math.pi * 2),
  );

  // Per-size caches so nothing is allocated per frame.
  Size? _size;
  late Paint _glow;
  late Path _rays;
  final _ray = Paint()..color = const Color(0x22FFFFFF);
  final _sunOuter = Paint()..color = const Color(0xFFFFF3A8);
  final _sunInner = Paint()..color = const Color(0xFFFFE15A);
  final _cloud = Paint()..color = const Color(0xF2FFFFFF);
  final _cloudShade = Paint()..color = const Color(0x22000000);
  final _spark = Paint();

  void _prepare(Size s) {
    if (_size == s) return;
    _size = s;
    final w = s.width;
    final sun = Offset(w * 0.82, s.height * 0.1);
    _glow = Paint()
      ..shader = const RadialGradient(colors: [Color(0x66FFF6B0), Color(0x00FFF6B0)])
          .createShader(Rect.fromCircle(center: sun, radius: w * 0.45));
    _rays = Path();
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      _rays
        ..moveTo(0, 0)
        ..lineTo(math.cos(a - 0.07) * w * 0.7, math.sin(a - 0.07) * w * 0.7)
        ..lineTo(math.cos(a + 0.07) * w * 0.7, math.sin(a + 0.07) * w * 0.7)
        ..close();
    }
  }

  @override
  void paint(Canvas canvas, Size s) {
    _prepare(s);
    final t = anim.value;
    final w = s.width, h = s.height;
    final sun = Offset(w * 0.82, h * 0.1);

    canvas.drawCircle(sun, w * 0.45, _glow);
    canvas.save();
    canvas.translate(sun.dx, sun.dy);
    canvas.rotate(t * math.pi * 2);
    canvas.drawPath(_rays, _ray);
    canvas.restore();
    canvas.drawCircle(sun, w * 0.075, _sunOuter);
    canvas.drawCircle(sun, w * 0.055, _sunInner);

    for (final (x0, y, scale, speed) in _clouds) {
      final cw = w * 0.32 * scale;
      final x = ((x0 + t * speed * 2) % 1.3) * (w + cw) - cw;
      _drawCloud(canvas, Offset(x, h * y), cw);
    }

    for (final (x, y, phase) in _sparkles) {
      final tw = (math.sin(t * math.pi * 2 * 12 + phase) + 1) / 2;
      if (tw < 0.4) continue;
      _drawSparkle(canvas, Offset(x * w, y * h), 2 + 5 * tw, tw);
    }
  }

  void _drawCloud(Canvas canvas, Offset o, double cw) {
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(o.dx, o.dy + cw * 0.14, cw, cw * 0.22),
      Radius.circular(cw * 0.11),
    );
    canvas.drawRRect(base.shift(Offset(0, cw * 0.05)), _cloudShade);
    canvas.drawRRect(base, _cloud);
    canvas.drawCircle(o + Offset(cw * 0.25, cw * 0.18), cw * 0.18, _cloud);
    canvas.drawCircle(o + Offset(cw * 0.5, cw * 0.1), cw * 0.24, _cloud);
    canvas.drawCircle(o + Offset(cw * 0.75, cw * 0.2), cw * 0.17, _cloud);
  }

  void _drawSparkle(Canvas canvas, Offset c, double s, double alpha) {
    _spark.color = Colors.white.withValues(alpha: alpha);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy - s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s),
      _spark,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => false;
}

/// Hills, castle, trees and flowers — static, so painted once and cached by its boundary.
class _SceneryPainter extends CustomPainter {
  const _SceneryPainter();

  static final _rand = math.Random(23);
  static final _flowers = List.generate(22, (i) => (_rand.nextDouble(), _rand.nextDouble(), i % 4));

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final far = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.25, h * 0.6, w * 0.5, h * 0.68)
      ..quadraticBezierTo(w * 0.78, h * 0.58, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(far, Paint()..color = const Color(0xFF9BE3A6));
    _castle(canvas, Offset(w * 0.73, h * 0.6), w * 0.16);

    final mid = Path()
      ..moveTo(0, h * 0.8)
      ..quadraticBezierTo(w * 0.3, h * 0.7, w * 0.62, h * 0.78)
      ..quadraticBezierTo(w * 0.85, h * 0.83, w, h * 0.76)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(mid, Paint()..color = const Color(0xFF62D058));
    for (final (x, y, sc) in [(0.12, 0.76, 1.0), (0.22, 0.745, 0.8), (0.88, 0.775, 1.1), (0.46, 0.755, 0.7)]) {
      _tree(canvas, Offset(w * x, h * y), w * 0.07 * sc);
    }

    final near = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.4, h * 0.82, w * 0.7, h * 0.87)
      ..quadraticBezierTo(w * 0.88, h * 0.9, w, h * 0.86)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(near, Paint()..color = const Color(0xFF3CB82F));
    const petals = [Color(0xFFFF6FB0), Color(0xFFFFE15A), Color(0xFFFFFFFF), Color(0xFFB98CFF)];
    final centre = Paint()..color = const Color(0xFFFFB300);
    for (final (x, y, c) in _flowers) {
      final p = Offset(w * x, h * (0.9 + y * 0.09));
      canvas.drawCircle(p, w * 0.009, Paint()..color = petals[c]);
      canvas.drawCircle(p, w * 0.0035, centre);
    }
  }

  void _tree(Canvas canvas, Offset base, double r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: base + Offset(0, -r * 0.6), width: r * 0.35, height: r * 1.2),
        Radius.circular(r * 0.1),
      ),
      Paint()..color = const Color(0xFF9C5B2E),
    );
    canvas.drawCircle(base + Offset(0, -r * 1.6), r, Paint()..color = const Color(0xFF2E9E3A));
    canvas.drawCircle(base + Offset(-r * 0.3, -r * 1.85), r * 0.45, Paint()..color = const Color(0xFF52C25A));
  }

  void _castle(Canvas canvas, Offset base, double size) {
    final wall = Paint()..color = const Color(0xFFF4E7FF);
    final shade = Paint()..color = const Color(0xFFD9C6F2);
    final roof = Paint()..color = const Color(0xFFFF5FA0);
    final body = Rect.fromLTWH(base.dx - size * 0.5, base.dy - size * 0.5, size, size * 0.5);
    canvas.drawRect(body, wall);
    canvas.drawRect(Rect.fromLTWH(body.left, body.bottom - size * 0.08, body.width, size * 0.08), shade);
    for (final (dx, tw, th) in [(-0.62, 0.26, 0.85), (0.36, 0.26, 0.85), (-0.12, 0.24, 1.05)]) {
      final tower = Rect.fromLTWH(base.dx + size * dx, base.dy - size * th, size * tw, size * th);
      canvas.drawRect(tower, wall);
      canvas.drawPath(
        Path()
          ..moveTo(tower.left - size * 0.04, tower.top)
          ..lineTo(tower.center.dx, tower.top - size * 0.3)
          ..lineTo(tower.right + size * 0.04, tower.top)
          ..close(),
        roof,
      );
      canvas.drawRect(
        Rect.fromLTWH(tower.center.dx - size * 0.03, tower.top + size * 0.12, size * 0.06, size * 0.1),
        shade,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(base.dx - size * 0.1, base.dy - size * 0.24, size * 0.2, size * 0.24),
        topLeft: Radius.circular(size * 0.1),
        topRight: Radius.circular(size * 0.1),
      ),
      Paint()..color = const Color(0xFF9C5B2E),
    );
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter old) => false;
}
