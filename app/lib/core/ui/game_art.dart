import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hand-drawn vector art for the economy & reward icons (no bitmap assets).
enum ArtKind { coin, gem, heart, star, starEmpty, bulb, chest, crown, bolt }

class GameArt extends StatelessWidget {
  const GameArt(this.kind, {super.key, this.size = 28});
  final ArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _ArtPainter(kind)),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.kind);
  final ArtKind kind;

  @override
  void paint(Canvas canvas, Size s) {
    switch (kind) {
      case ArtKind.coin:
        _coin(canvas, s);
      case ArtKind.gem:
        _gem(canvas, s);
      case ArtKind.heart:
        _heart(canvas, s);
      case ArtKind.star:
        _star(canvas, s, filled: true);
      case ArtKind.starEmpty:
        _star(canvas, s, filled: false);
      case ArtKind.bulb:
        _bulb(canvas, s);
      case ArtKind.chest:
        _chest(canvas, s);
      case ArtKind.crown:
        _crown(canvas, s);
      case ArtKind.bolt:
        _bolt(canvas, s);
    }
  }

  void _gloss(Canvas c, Rect r) {
    c.drawOval(
      Rect.fromLTWH(r.left + r.width * 0.22, r.top + r.height * 0.12, r.width * 0.32, r.height * 0.18),
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }

  void _coin(Canvas c, Size s) {
    final r = s.width / 2;
    final ctr = Offset(r, r);
    c.drawCircle(ctr.translate(0, r * 0.08), r * 0.96, Paint()..color = const Color(0xFFB86B00));
    c.drawCircle(
      ctr,
      r * 0.92,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3A0), Color(0xFFFFC21A), Color(0xFFF09000)],
        ).createShader(Offset.zero & s),
    );
    c.drawCircle(
      ctr,
      r * 0.66,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..color = const Color(0xFFE08A00).withValues(alpha: 0.65),
    );
    // Embossed star.
    _starPath(c, ctr, r * 0.42, const Color(0xFFFFF7C2));
    _gloss(c, Offset.zero & s);
  }

  void _gem(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final outline = Path()
      ..moveTo(w * 0.22, h * 0.12)
      ..lineTo(w * 0.78, h * 0.12)
      ..lineTo(w * 0.98, h * 0.38)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.02, h * 0.38)
      ..close();
    c.drawShadow(outline, Colors.black, 2, false);
    c.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF9BE2), Color(0xFFE81FA8), Color(0xFF9B0B78)],
        ).createShader(Offset.zero & s),
    );
    final facet = Paint()..color = Colors.white.withValues(alpha: 0.35);
    c.drawPath(
      Path()
        ..moveTo(w * 0.22, h * 0.12)
        ..lineTo(w * 0.5, h * 0.38)
        ..lineTo(w * 0.02, h * 0.38)
        ..close(),
      facet,
    );
    c.drawPath(
      Path()
        ..moveTo(w * 0.5, h * 0.38)
        ..lineTo(w * 0.78, h * 0.12)
        ..lineTo(w * 0.22, h * 0.12)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    c.drawPath(
      Path()
        ..moveTo(w * 0.02, h * 0.38)
        ..lineTo(w * 0.98, h * 0.38)
        ..lineTo(w * 0.5, h * 0.95)
        ..close(),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    c.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF7A0560),
    );
  }

  Path _heartPath(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * 0.5, h * 0.92)
      ..cubicTo(w * -0.15, h * 0.48, w * 0.12, h * -0.08, w * 0.5, h * 0.26)
      ..cubicTo(w * 0.88, h * -0.08, w * 1.15, h * 0.48, w * 0.5, h * 0.92)
      ..close();
  }

  void _heart(Canvas c, Size s) {
    final p = _heartPath(s);
    c.save();
    c.translate(0, s.height * 0.05);
    c.drawPath(p, Paint()..color = const Color(0xFF9E0A33));
    c.restore();
    c.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8FA8), Color(0xFFFF2D5A), Color(0xFFD10F3E)],
        ).createShader(Offset.zero & s),
    );
    c.drawOval(
      Rect.fromLTWH(s.width * 0.18, s.height * 0.18, s.width * 0.22, s.height * 0.14),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  void _starPath(Canvas c, Offset ctr, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.48;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = ctr + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = color);
  }

  void _star(Canvas c, Size s, {required bool filled}) {
    final r = s.width / 2;
    final ctr = Offset(r, r * 1.06);
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r * 0.98 : r * 0.5;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = ctr + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    if (!filled) {
      c.drawPath(path, Paint()..color = const Color(0x55000000));
      c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.1
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white.withValues(alpha: 0.35),
      );
      return;
    }
    c.save();
    c.translate(0, r * 0.08);
    c.drawPath(path, Paint()..color = const Color(0xFFC06A00));
    c.restore();
    c.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF59A), Color(0xFFFFCC1A), Color(0xFFFF9800)],
        ).createShader(Offset.zero & s),
    );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFD27A00),
    );
    c.drawOval(
      Rect.fromLTWH(s.width * 0.36, s.height * 0.26, s.width * 0.16, s.height * 0.12),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
  }

  void _bulb(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final glass = Rect.fromCircle(center: Offset(w * 0.5, h * 0.4), radius: w * 0.34);
    c.drawCircle(glass.center, w * 0.46, Paint()..color = const Color(0x44FFE066));
    c.drawOval(
      glass,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFFFFDE0), Color(0xFFFFD233), Color(0xFFF59E00)],
        ).createShader(glass),
    );
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.33, h * 0.68, w * 0.34, h * 0.24),
      Radius.circular(w * 0.06),
    );
    c.drawRRect(base, Paint()..color = const Color(0xFF8E9AB8));
    c.drawLine(
      Offset(w * 0.35, h * 0.76),
      Offset(w * 0.65, h * 0.76),
      Paint()
        ..color = const Color(0xFF5E6A88)
        ..strokeWidth = h * 0.04,
    );
    _gloss(c, glass);
  }

  void _chest(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.42, w * 0.88, h * 0.5),
      Radius.circular(w * 0.08),
    );
    final lid = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.06, h * 0.14, w * 0.88, h * 0.32),
      topLeft: Radius.circular(w * 0.3),
      topRight: Radius.circular(w * 0.3),
    );
    final wood = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFD9822B), Color(0xFF9A4A12)],
      ).createShader(Offset.zero & s);
    c.drawRRect(body, wood);
    c.drawRRect(lid, wood);
    final band = Paint()..color = const Color(0xFFFFC21A);
    c.drawRect(Rect.fromLTWH(w * 0.06, h * 0.4, w * 0.88, h * 0.07), band);
    c.drawRect(Rect.fromLTWH(w * 0.2, h * 0.14, w * 0.08, h * 0.78), band);
    c.drawRect(Rect.fromLTWH(w * 0.72, h * 0.14, w * 0.08, h * 0.78), band);
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.41, h * 0.38, w * 0.18, h * 0.22), Radius.circular(w * 0.04)),
      Paint()..color = const Color(0xFFFFE680),
    );
    c.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.035, Paint()..color = const Color(0xFF6B3200));
  }

  void _crown(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.08, h * 0.3)
      ..lineTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.5, h * 0.15)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w * 0.92, h * 0.3)
      ..lineTo(w * 0.84, h * 0.82)
      ..lineTo(w * 0.16, h * 0.82)
      ..close();
    c.save();
    c.translate(0, h * 0.05);
    c.drawPath(p, Paint()..color = const Color(0xFFB86B00));
    c.restore();
    c.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF59A), Color(0xFFFFC21A), Color(0xFFF59000)],
        ).createShader(Offset.zero & s),
    );
    for (final x in [0.08, 0.5, 0.92]) {
      c.drawCircle(Offset(w * x, h * (x == 0.5 ? 0.15 : 0.3)), w * 0.07, Paint()..color = const Color(0xFFFF3D7F));
    }
    c.drawRect(
      Rect.fromLTWH(w * 0.16, h * 0.7, w * 0.68, h * 0.06),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  void _bolt(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final p = Path()
      ..moveTo(w * 0.58, h * 0.04)
      ..lineTo(w * 0.16, h * 0.56)
      ..lineTo(w * 0.46, h * 0.56)
      ..lineTo(w * 0.38, h * 0.96)
      ..lineTo(w * 0.84, h * 0.4)
      ..lineTo(w * 0.54, h * 0.4)
      ..close();
    c.drawPath(
      p,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFFFF59A), Color(0xFFFFA800)]).createShader(Offset.zero & s),
    );
    c.drawPath(
      p,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFC06A00),
    );
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.kind != kind;
}
