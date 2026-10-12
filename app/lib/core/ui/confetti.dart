import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lightweight particle system: confetti ribbons + star sparks bursting from a point
/// with gravity, drag and spin. Call [ConfettiController.burst] to fire.
class ConfettiController extends ChangeNotifier {
  final List<_Particle> _parts = [];
  final _rand = math.Random();

  static const _colors = [
    Color(0xFFFF3D7F),
    Color(0xFFFFC21A),
    Color(0xFF2E8BFF),
    Color(0xFF22D36B),
    Color(0xFF9B4DFF),
    Color(0xFF14C8C0),
    Color(0xFFFF7A1A),
  ];

  void burst({Offset origin = const Offset(0.5, 0.35), int count = 140, double power = 1}) {
    for (var i = 0; i < count; i++) {
      final a = _rand.nextDouble() * math.pi * 2;
      final v = (300 + _rand.nextDouble() * 900) * power;
      _parts.add(_Particle(
        pos: origin,
        vel: Offset(math.cos(a) * v, math.sin(a) * v - 500 * power),
        color: _colors[_rand.nextInt(_colors.length)],
        size: 6 + _rand.nextDouble() * 8,
        spin: (_rand.nextDouble() - 0.5) * 14,
        shape: _rand.nextInt(3),
        life: 2.2 + _rand.nextDouble() * 1.4,
      ));
    }
    notifyListeners();
  }

  /// Steady rain from the top edge (used on big wins).
  void rain({int count = 80}) {
    for (var i = 0; i < count; i++) {
      _parts.add(_Particle(
        pos: Offset(_rand.nextDouble(), -0.05 - _rand.nextDouble() * 0.4),
        vel: Offset((_rand.nextDouble() - 0.5) * 120, 80 + _rand.nextDouble() * 200),
        color: _colors[_rand.nextInt(_colors.length)],
        size: 6 + _rand.nextDouble() * 7,
        spin: (_rand.nextDouble() - 0.5) * 10,
        shape: _rand.nextInt(3),
        life: 4 + _rand.nextDouble() * 2,
      ));
    }
    notifyListeners();
  }

  bool get active => _parts.isNotEmpty;

  void _step(double dt, Size size) {
    for (final p in _parts) {
      p.age += dt;
      p.vel = Offset(p.vel.dx * (1 - 1.6 * dt), p.vel.dy * (1 - 1.2 * dt) + 1100 * dt);
      p.px += p.vel.dx * dt;
      p.py += p.vel.dy * dt;
      p.rot += p.spin * dt;
    }
    _parts.removeWhere((p) => p.age > p.life || p.py > size.height + 40);
  }
}

class _Particle {
  _Particle({
    required Offset pos,
    required this.vel,
    required this.color,
    required this.size,
    required this.spin,
    required this.shape,
    required this.life,
  })  : rx = pos.dx,
        ry = pos.dy;

  // Relative spawn position, resolved to pixels on first frame.
  final double rx, ry;
  double px = double.nan, py = double.nan;
  Offset vel;
  final Color color;
  final double size, spin, life;
  final int shape;
  double rot = 0, age = 0;
}

class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({super.key, required this.controller});
  final ConfettiController controller;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController.unbounded(vsync: this);
  Duration _last = Duration.zero;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onBurst);
    _ticker.addListener(_tick);
  }

  void _onBurst() {
    if (!_ticker.isAnimating) {
      _last = Duration.zero;
      _ticker.repeat(min: 0, max: 1, period: const Duration(seconds: 1));
    }
  }

  void _tick() {
    final now = _ticker.lastElapsedDuration ?? Duration.zero;
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0 || dt > 0.05) dt = 1 / 60;
    for (final p in widget.controller._parts) {
      if (p.px.isNaN) {
        p.px = p.rx * _size.width;
        p.py = p.ry * _size.height;
      }
    }
    widget.controller._step(dt, _size);
    if (!widget.controller.active) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBurst);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(builder: (context, c) {
        _size = c.biggest;
        return CustomPaint(size: c.biggest, painter: _ConfettiPainter(widget.controller._parts));
      }),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.parts);
  final List<_Particle> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in parts) {
      if (p.px.isNaN) continue;
      final fade = (1 - ((p.age - p.life + 0.6) / 0.6).clamp(0.0, 1.0));
      paint.color = p.color.withValues(alpha: fade);
      canvas.save();
      canvas.translate(p.px, p.py);
      canvas.rotate(p.rot);
      // Fake 3D flutter by squashing one axis.
      canvas.scale(1, math.cos(p.rot * 1.7).abs() * 0.8 + 0.2);
      switch (p.shape) {
        case 0:
          canvas.drawRRect(
              RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
                  const Radius.circular(2)),
              paint);
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.38, paint);
        default:
          final r = p.size * 0.55;
          final path = Path();
          for (var i = 0; i < 8; i++) {
            final rad = i.isEven ? r : r * 0.35;
            final a = i * math.pi / 4;
            final pt = Offset(math.cos(a) * rad, math.sin(a) * rad);
            i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
          }
          canvas.drawPath(path..close(), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
