import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Living backdrop: rich gradient, a soft radial glow, slow-drifting bokeh orbs
/// and twinkling sparkles. Freezes when the user prefers reduced motion.
class CandyBackground extends StatefulWidget {
  const CandyBackground({
    super.key,
    required this.child,
    this.gradient = AppColors.worldBg,
    this.orbColors = const [Color(0xFFFF6EC7), Color(0xFF7AF5FF), Color(0xFFFFE066), Color(0xFFB98CFF)],
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 30));
  late final List<_Orb> _orbs;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    _orbs = List.generate(widget.density, (i) {
      return _Orb(
        x: r.nextDouble(),
        y: r.nextDouble(),
        radius: 18 + r.nextDouble() * 70,
        speed: 0.3 + r.nextDouble() * 0.9,
        phase: r.nextDouble() * math.pi * 2,
        color: widget.orbColors[i % widget.orbColors.length],
        sparkle: i.isEven,
      );
    });
  }

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
          // Top glow, like stage light.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -1.1),
                radius: 1.1,
                colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
              ),
            ),
          ),
          RepaintBoundary(
            child: CustomPaint(painter: _OrbPainter(_orbs, _c)),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Orb {
  _Orb({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.phase,
    required this.color,
    required this.sparkle,
  });
  final double x, y, radius, speed, phase;
  final Color color;
  final bool sparkle;
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.orbs, this.anim) : super(repaint: anim);
  final List<_Orb> orbs;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value * math.pi * 2;
    for (final o in orbs) {
      final dx = math.sin(t * o.speed + o.phase) * 24;
      final dy = ((o.y - anim.value * o.speed * 0.25) % 1.0) * (size.height + 2 * o.radius) - o.radius;
      final center = Offset(o.x * size.width + dx, dy);
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          o.color.withValues(alpha: 0.38),
          o.color.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: center, radius: o.radius));
      canvas.drawCircle(center, o.radius, paint);
      if (o.sparkle) {
        final tw = (math.sin(t * 3 * o.speed + o.phase) + 1) / 2;
        _sparkle(canvas, center.translate(o.radius * 0.4, -o.radius * 0.3), 3 + 5 * tw, 0.35 + 0.6 * tw);
      }
    }
  }

  void _sparkle(Canvas canvas, Offset c, double s, double alpha) {
    final p = Paint()..color = Colors.white.withValues(alpha: alpha);
    final path = Path()
      ..moveTo(c.dx, c.dy - s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + s)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - s, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - s);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => false;
}
